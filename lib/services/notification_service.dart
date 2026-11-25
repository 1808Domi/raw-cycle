import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../features/cycle_tracking/data/database_service.dart';
import '../features/settings/data/settings_service.dart';
import 'cycle_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int dailyReminderId = 1001;
  static const int periodReminderId = 1002;
  static const int ovulationReminderId = 1003;

  static const _channelId = 'raw_cycle_reminders';
  static const _channelName = 'Zykluserinnerungen';
  static const _channelDescription =
      'Erinnerungen für Periode, Eisprung und tägliche Einträge';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;
  timezone.Location? _localLocation;
  AndroidScheduleMode? _androidScheduleMode;
  bool _exactAlarmPermissionRequested = false;
  Future<void> _settingsSyncQueue = Future<void>.value();
  StreamSubscription<void>? _cycleEntrySubscription;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    _localLocation = timezone.getLocation(localTimezone.identifier);

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    final initialized = await _notifications.initialize(initializationSettings);
    if (initialized != true) {
      throw StateError(
        'Lokale Benachrichtigungen konnten nicht initialisiert werden.',
      );
    }
  }

  Future<void> scheduleDailyReminder({required TimeOfDay time}) async {
    await initialize();
    final androidScheduleMode = await _preparePermissions();
    final firstOccurrence = _nextDailyOccurrence(time);

    await _notifications.zonedSchedule(
      dailyReminderId,
      'Zeit für deinen Zykluseintrag',
      'Nimm dir einen Moment, um deinen heutigen Zyklus festzuhalten.',
      firstOccurrence,
      _notificationDetails,
      androidScheduleMode: androidScheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> schedulePeriodReminder({
    required DateTime predictedPeriodDate,
    required TimeOfDay time,
    int daysBefore = 0,
  }) async {
    _validateLeadDays(daysBefore);
    await initialize();
    final scheduledDate = _cycleReminderDate(
      predictedDate: predictedPeriodDate,
      time: time,
      daysBefore: daysBefore,
    );
    final androidScheduleMode = await _preparePermissions();

    await _notifications.zonedSchedule(
      periodReminderId,
      'Deine Periode steht bevor',
      daysBefore == 0
          ? 'Deine Periode wird voraussichtlich heute beginnen.'
          : 'Deine Periode wird voraussichtlich in $daysBefore '
                '${daysBefore == 1 ? 'Tag' : 'Tagen'} beginnen.',
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: androidScheduleMode,
    );
  }

  Future<void> scheduleOvulationReminder({
    required DateTime predictedOvulationDate,
    required TimeOfDay time,
    int daysBefore = 0,
  }) async {
    _validateLeadDays(daysBefore);
    await initialize();
    final scheduledDate = _cycleReminderDate(
      predictedDate: predictedOvulationDate,
      time: time,
      daysBefore: daysBefore,
    );
    final androidScheduleMode = await _preparePermissions();

    await _notifications.zonedSchedule(
      ovulationReminderId,
      'Dein Eisprung steht bevor',
      daysBefore == 0
          ? 'Dein Eisprung wird voraussichtlich heute stattfinden.'
          : 'Dein Eisprung wird voraussichtlich in $daysBefore '
                '${daysBefore == 1 ? 'Tag' : 'Tagen'} stattfinden.',
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: androidScheduleMode,
    );
  }

  Future<void> cancelNotification(int id) async {
    await initialize();
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await initialize();
    await _notifications.cancelAll();
  }

  Future<void> syncWithSettings(
    CycleSettings settings, {
    bool syncDaily = true,
    bool syncPeriod = true,
    bool syncOvulation = true,
  }) {
    final completer = Completer<void>();
    _settingsSyncQueue = _settingsSyncQueue.then((_) async {
      try {
        await initialize();
        if (syncDaily) {
          if (settings.dailyReminderEnabled) {
            await scheduleDailyReminder(
              time: _parseTime(settings.dailyReminderTime),
            );
          } else {
            await cancelNotification(dailyReminderId);
          }
        }
        if (syncPeriod) {
          await _syncPeriodReminder(settings);
        }
        if (syncOvulation) {
          await _syncOvulationReminder(settings);
        }
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void observeCycleEntryChanges() {
    _cycleEntrySubscription ??= DatabaseService.instance
        .watchCycleEntryChanges()
        .listen(
          (_) async {
            try {
              final settings = await SettingsService.instance.load();
              await syncWithSettings(
                settings,
                syncDaily: false,
                syncPeriod: true,
                syncOvulation: true,
              );
            } catch (error, stackTrace) {
              debugPrint(
                'Cycle reminder rescheduling failed: $error\n$stackTrace',
              );
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Cycle entry change stream failed: $error\n$stackTrace');
          },
        );
  }

  Future<void> _syncPeriodReminder(CycleSettings settings) async {
    if (!settings.periodReminderEnabled) {
      await cancelNotification(periodReminderId);
      return;
    }

    final predictedDate = await CycleService.instance.getNextPeriodDate();
    if (predictedDate == null) {
      await cancelNotification(periodReminderId);
      return;
    }

    try {
      await schedulePeriodReminder(
        predictedPeriodDate: predictedDate,
        time: _parseTime(settings.periodReminderTime),
        daysBefore: settings.periodReminderLeadDays,
      );
    } on ArgumentError catch (error) {
      await cancelNotification(periodReminderId);
      debugPrint('Period reminder could not be scheduled: $error');
    }
  }

  Future<void> _syncOvulationReminder(CycleSettings settings) async {
    if (!settings.ovulationReminderEnabled) {
      await cancelNotification(ovulationReminderId);
      return;
    }

    final predictedDate = await CycleService.instance.getNextOvulationDate();
    if (predictedDate == null) {
      await cancelNotification(ovulationReminderId);
      return;
    }

    try {
      await scheduleOvulationReminder(
        predictedOvulationDate: predictedDate,
        time: _parseTime(settings.ovulationReminderTime),
        daysBefore: settings.ovulationReminderLeadDays,
      );
    } on ArgumentError catch (error) {
      await cancelNotification(ovulationReminderId);
      debugPrint('Ovulation reminder could not be scheduled: $error');
    }
  }

  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<AndroidScheduleMode> _preparePermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsAllowed = await android
          ?.requestNotificationsPermission();
      if (notificationsAllowed == false) {
        throw StateError('Die Benachrichtigungsberechtigung wurde abgelehnt.');
      }

      final exactPermissionAlreadyGranted =
          await android?.canScheduleExactNotifications() ?? false;
      if (exactPermissionAlreadyGranted) {
        _androidScheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      } else if (!_exactAlarmPermissionRequested) {
        _exactAlarmPermissionRequested = true;
        final exactPermissionGranted =
            await android?.requestExactAlarmsPermission() ?? false;
        _androidScheduleMode = exactPermissionGranted
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;
      } else {
        _androidScheduleMode ??= AndroidScheduleMode.inexactAllowWhileIdle;
      }
      return _androidScheduleMode!;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final notificationsAllowed = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (notificationsAllowed == false) {
        throw StateError('Die Benachrichtigungsberechtigung wurde abgelehnt.');
      }
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  timezone.TZDateTime _nextDailyOccurrence(TimeOfDay time) {
    final location = _requireLocalLocation();
    final now = timezone.TZDateTime.now(location);
    var occurrence = timezone.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!occurrence.isAfter(now)) {
      occurrence = timezone.TZDateTime(
        location,
        now.year,
        now.month,
        now.day + 1,
        time.hour,
        time.minute,
      );
    }
    return occurrence;
  }

  timezone.TZDateTime _cycleReminderDate({
    required DateTime predictedDate,
    required TimeOfDay time,
    required int daysBefore,
  }) {
    final location = _requireLocalLocation();
    final scheduledDate = timezone.TZDateTime(
      location,
      predictedDate.year,
      predictedDate.month,
      predictedDate.day - daysBefore,
      time.hour,
      time.minute,
    );
    if (!scheduledDate.isAfter(timezone.TZDateTime.now(location))) {
      throw ArgumentError.value(
        predictedDate,
        'predictedDate',
        'Der Erinnerungstermin muss in der Zukunft liegen.',
      );
    }
    return scheduledDate;
  }

  timezone.Location _requireLocalLocation() {
    final location = _localLocation;
    if (location == null) {
      throw StateError(
        'NotificationService.initialize() wurde nicht abgeschlossen.',
      );
    }
    return location;
  }

  static void _validateLeadDays(int daysBefore) {
    if (daysBefore < 0 || daysBefore > 3) {
      throw ArgumentError.value(
        daysBefore,
        'daysBefore',
        'Die Vorlaufzeit muss zwischen 0 und 3 Tagen liegen.',
      );
    }
  }

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );
}
