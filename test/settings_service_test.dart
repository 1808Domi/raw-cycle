import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:raw_cycle/features/cycle_tracking/data/database_service.dart';
import 'package:raw_cycle/features/cycle_tracking/data/models/cycle_entry.dart';
import 'package:raw_cycle/features/settings/data/backup_service.dart';
import 'package:raw_cycle/features/settings/data/settings_service.dart';
import 'package:raw_cycle/services/cycle_service.dart';

void main() {
  late Directory databaseDirectory;
  final database = DatabaseService.instance;
  final settings = SettingsService.instance;

  setUpAll(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'raw_cycle_settings_',
    );
    Hive.init(databaseDirectory.path);
    await database.init();
    await settings.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await databaseDirectory.delete(recursive: true);
  });

  test(
    'uses scientific defaults when no period history is available',
    () async {
      const preferences = CycleSettings(
        periodReminderEnabled: true,
        periodReminderTime: '07:30',
        periodReminderLeadDays: 2,
        ovulationReminderEnabled: true,
        ovulationReminderTime: '08:15',
        ovulationReminderLeadDays: 3,
        dailyReminderEnabled: true,
        dailyReminderTime: '20:45',
        appProtectionEnabled: true,
        appProtectionMethod: AppProtectionMethod.pin,
        appProtectionCheckMode: AppProtectionCheckMode.afterInactivity,
      );
      await settings.save(preferences);

      final restoredPreferences = await settings.load();
      expect(restoredPreferences.periodReminderEnabled, isTrue);
      expect(restoredPreferences.periodReminderTime, '07:30');
      expect(restoredPreferences.periodReminderLeadDays, 2);
      expect(restoredPreferences.ovulationReminderEnabled, isTrue);
      expect(restoredPreferences.ovulationReminderTime, '08:15');
      expect(restoredPreferences.ovulationReminderLeadDays, 3);
      expect(restoredPreferences.dailyReminderEnabled, isTrue);
      expect(restoredPreferences.dailyReminderTime, '20:45');
      expect(restoredPreferences.appProtectionEnabled, isTrue);
      expect(restoredPreferences.appProtectionMethod, AppProtectionMethod.pin);
      expect(
        restoredPreferences.appProtectionCheckMode,
        AppProtectionCheckMode.afterInactivity,
      );

      final service = CycleService(
        entriesProvider: () async => const [],
        clock: () => DateTime(2026, 11, 25),
      );
      expect(await service.getAverageCycleLength(), 28);
      expect(await service.getAveragePeriodLength(), 5);
    },
  );

  test('migrates the previous shared reminder time to each reminder', () {
    final settings = CycleSettings.fromJson({'reminderTime': '19:45'});

    expect(settings.periodReminderTime, '19:45');
    expect(settings.ovulationReminderTime, '19:45');
    expect(settings.dailyReminderTime, '19:45');
    expect(settings.periodReminderLeadDays, 0);
    expect(settings.ovulationReminderLeadDays, 0);
    expect(settings.appProtectionEnabled, isFalse);
    expect(settings.appProtectionMethod, AppProtectionMethod.deviceUnlock);
    expect(
      settings.appProtectionCheckMode,
      AppProtectionCheckMode.appStartOnly,
    );
  });

  test('imports a backup replacing saved entries and settings', () async {
    final entry = CycleEntry(
      id: 'backup-entry',
      date: DateTime(2026, 11, 24),
      isPeriodDay: true,
      bleedingIntensity: BleedingIntensity.mittel,
      temperature: 36.7,
      symptoms: const ['Krämpfe'],
      notes: 'Backup-Notiz',
      cervicalMucus: CervicalMucus.cremig,
      mood: Mood.neutral,
      energyLevel: EnergyLevel.normal,
      sleepHours: 7.5,
    );
    final backup = {
      'formatVersion': 1,
      'createdAt': DateTime(2026, 11, 25).toIso8601String(),
      'settings': {
        ...const CycleSettings(
          periodReminderEnabled: true,
          periodReminderTime: '07:30',
          periodReminderLeadDays: 2,
          ovulationReminderEnabled: true,
          ovulationReminderTime: '08:15',
          ovulationReminderLeadDays: 3,
          dailyReminderEnabled: true,
          dailyReminderTime: '20:45',
          temperatureMeasurement: TemperatureMeasurement.vaginal,
          appProtectionEnabled: true,
          appProtectionMethod: AppProtectionMethod.biometrics,
          appProtectionCheckMode: AppProtectionCheckMode.afterInactivity,
        ).toJson(),
        'standardCycleLength': 30,
        'standardPeriodLength': 4,
      },
      'entries': [entry.toJson()],
    };

    await BackupService.importBackup(
      Uint8List.fromList(utf8.encode(jsonEncode(backup))),
    );

    final importedEntries = await database.getAllCycleEntries();
    expect(importedEntries, hasLength(1));
    expect(importedEntries.single.id, entry.id);
    expect(importedEntries.single.date, entry.date);
    expect(importedEntries.single.isPeriodDay, isTrue);
    expect(importedEntries.single.bleedingIntensity, BleedingIntensity.mittel);
    expect(importedEntries.single.temperature, 36.7);
    expect(importedEntries.single.symptoms, ['Krämpfe']);
    expect(importedEntries.single.notes, 'Backup-Notiz');
    expect(importedEntries.single.cervicalMucus, CervicalMucus.cremig);
    expect(importedEntries.single.mood, Mood.neutral);
    expect(importedEntries.single.energyLevel, EnergyLevel.normal);
    expect(importedEntries.single.sleepHours, 7.5);
    final restoredSettings = await settings.load();
    expect(restoredSettings.periodReminderEnabled, isTrue);
    expect(restoredSettings.periodReminderTime, '07:30');
    expect(restoredSettings.periodReminderLeadDays, 2);
    expect(restoredSettings.ovulationReminderEnabled, isTrue);
    expect(restoredSettings.ovulationReminderTime, '08:15');
    expect(restoredSettings.ovulationReminderLeadDays, 3);
    expect(restoredSettings.dailyReminderEnabled, isTrue);
    expect(restoredSettings.dailyReminderTime, '20:45');
    expect(
      restoredSettings.temperatureMeasurement,
      TemperatureMeasurement.vaginal,
    );
    expect(restoredSettings.appProtectionEnabled, isTrue);
    expect(
      restoredSettings.appProtectionMethod,
      AppProtectionMethod.biometrics,
    );
    expect(
      restoredSettings.appProtectionCheckMode,
      AppProtectionCheckMode.afterInactivity,
    );
  });

  test('rejects malformed backups without changing saved data', () async {
    final existingEntry = CycleEntry(
      id: 'existing-entry',
      date: DateTime(2026, 11, 25),
      isPeriodDay: false,
      symptoms: const ['Müdigkeit'],
    );
    const existingSettings = CycleSettings(
      dailyReminderEnabled: true,
      dailyReminderTime: '09:15',
    );
    await database.replaceAllCycleEntries([existingEntry]);
    await settings.save(existingSettings);

    final malformedBackup = {
      'formatVersion': 1,
      'createdAt': DateTime(2026, 11, 25).toIso8601String(),
      'settings': const CycleSettings().toJson(),
      'entries': ['not an entry'],
    };

    await expectLater(
      BackupService.importBackup(utf8.encode(jsonEncode(malformedBackup))),
      throwsFormatException,
    );

    expect(await database.getAllCycleEntries(), [existingEntry]);
    expect(await settings.load(), isA<CycleSettings>());
    final restoredSettings = await settings.load();
    expect(restoredSettings.dailyReminderEnabled, isTrue);
    expect(restoredSettings.dailyReminderTime, '09:15');
  });
}
