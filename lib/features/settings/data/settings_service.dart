import 'dart:async';
import 'dart:convert';

import 'package:hive_ce/hive.dart';

enum TemperatureMeasurement { oral, vaginal, rectal, axillary }

enum AppProtectionMethod { deviceUnlock, pin, biometrics }

enum AppProtectionCheckMode { appStartOnly, afterInactivity }

class CycleSettings {
  const CycleSettings({
    this.periodReminderEnabled = false,
    this.ovulationReminderEnabled = false,
    this.dailyReminderEnabled = false,
    this.periodReminderTime = '20:00',
    this.periodReminderLeadDays = 0,
    this.ovulationReminderTime = '20:00',
    this.ovulationReminderLeadDays = 0,
    this.dailyReminderTime = '20:00',
    this.temperatureMeasurement = TemperatureMeasurement.oral,
    this.appProtectionEnabled = false,
    this.appProtectionMethod = AppProtectionMethod.deviceUnlock,
    this.appProtectionCheckMode = AppProtectionCheckMode.appStartOnly,
  });

  final bool periodReminderEnabled;
  final bool ovulationReminderEnabled;
  final bool dailyReminderEnabled;
  final String periodReminderTime;
  final int periodReminderLeadDays;
  final String ovulationReminderTime;
  final int ovulationReminderLeadDays;
  final String dailyReminderTime;
  final TemperatureMeasurement temperatureMeasurement;
  final bool appProtectionEnabled;
  final AppProtectionMethod appProtectionMethod;
  final AppProtectionCheckMode appProtectionCheckMode;

  CycleSettings copyWith({
    bool? periodReminderEnabled,
    bool? ovulationReminderEnabled,
    bool? dailyReminderEnabled,
    String? periodReminderTime,
    int? periodReminderLeadDays,
    String? ovulationReminderTime,
    int? ovulationReminderLeadDays,
    String? dailyReminderTime,
    TemperatureMeasurement? temperatureMeasurement,
    bool? appProtectionEnabled,
    AppProtectionMethod? appProtectionMethod,
    AppProtectionCheckMode? appProtectionCheckMode,
  }) {
    return CycleSettings(
      periodReminderEnabled:
          periodReminderEnabled ?? this.periodReminderEnabled,
      ovulationReminderEnabled:
          ovulationReminderEnabled ?? this.ovulationReminderEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      periodReminderTime: periodReminderTime ?? this.periodReminderTime,
      periodReminderLeadDays:
          periodReminderLeadDays ?? this.periodReminderLeadDays,
      ovulationReminderTime:
          ovulationReminderTime ?? this.ovulationReminderTime,
      ovulationReminderLeadDays:
          ovulationReminderLeadDays ?? this.ovulationReminderLeadDays,
      dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      temperatureMeasurement:
          temperatureMeasurement ?? this.temperatureMeasurement,
      appProtectionEnabled: appProtectionEnabled ?? this.appProtectionEnabled,
      appProtectionMethod: appProtectionMethod ?? this.appProtectionMethod,
      appProtectionCheckMode:
          appProtectionCheckMode ?? this.appProtectionCheckMode,
    );
  }

  Map<String, Object> toJson() => {
    'periodReminderEnabled': periodReminderEnabled,
    'ovulationReminderEnabled': ovulationReminderEnabled,
    'dailyReminderEnabled': dailyReminderEnabled,
    'periodReminderTime': periodReminderTime,
    'periodReminderLeadDays': periodReminderLeadDays,
    'ovulationReminderTime': ovulationReminderTime,
    'ovulationReminderLeadDays': ovulationReminderLeadDays,
    'dailyReminderTime': dailyReminderTime,
    'temperatureMeasurement': temperatureMeasurement.name,
    'appProtectionEnabled': appProtectionEnabled,
    'appProtectionMethod': appProtectionMethod.name,
    'appProtectionCheckMode': appProtectionCheckMode.name,
  };

  factory CycleSettings.fromJson(Map<String, dynamic> json) {
    final legacyReminderTime = json['reminderTime'] as String? ?? '20:00';
    return CycleSettings(
      periodReminderEnabled: json['periodReminderEnabled'] as bool? ?? false,
      ovulationReminderEnabled:
          json['ovulationReminderEnabled'] as bool? ?? false,
      dailyReminderEnabled: json['dailyReminderEnabled'] as bool? ?? false,
      periodReminderTime:
          json['periodReminderTime'] as String? ?? legacyReminderTime,
      periodReminderLeadDays: _readLeadDays(json, 'periodReminderLeadDays'),
      ovulationReminderTime:
          json['ovulationReminderTime'] as String? ?? legacyReminderTime,
      ovulationReminderLeadDays: _readLeadDays(
        json,
        'ovulationReminderLeadDays',
      ),
      dailyReminderTime:
          json['dailyReminderTime'] as String? ?? legacyReminderTime,
      temperatureMeasurement: TemperatureMeasurement.values.byName(
        json['temperatureMeasurement'] as String? ?? 'oral',
      ),
      appProtectionEnabled: json['appProtectionEnabled'] as bool? ?? false,
      appProtectionMethod: AppProtectionMethod.values.byName(
        json['appProtectionMethod'] as String? ?? 'deviceUnlock',
      ),
      appProtectionCheckMode: AppProtectionCheckMode.values.byName(
        json['appProtectionCheckMode'] as String? ?? 'appStartOnly',
      ),
    );
  }

  static int _readLeadDays(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return 0;
    }
    if (value is int && value >= 0 && value <= 3) {
      return value;
    }
    throw FormatException('Ungültige Vorlaufzeit: $key.');
  }
}

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();
  static const _boxName = 'raw_cycle_settings';
  static const _settingsKey = 'preferences';

  Future<void>? _initialization;
  Box<String>? _box;
  Future<void> _writeQueue = Future<void>.value();

  bool get isInitialized => _box?.isOpen ?? false;

  Future<void> init() => _initialization ??= _openBox();

  Future<void> _openBox() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  Future<CycleSettings> load() async {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('SettingsService.init() must be called before use.');
    }
    final json = box.get(_settingsKey);
    if (json == null) {
      return const CycleSettings();
    }
    return CycleSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Stream<CycleSettings> watch() {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('SettingsService.init() must be called before use.');
    }
    return box.watch(key: _settingsKey).map((event) {
      final json = event.value;
      if (json == null) {
        return const CycleSettings();
      }
      if (json is! String) {
        throw const FormatException(
          'Gespeicherte Einstellungen sind ungültig.',
        );
      }
      return CycleSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
    });
  }

  Future<void> save(CycleSettings settings) async {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('SettingsService.init() must be called before use.');
    }
    final completer = Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await box.put(_settingsKey, jsonEncode(settings.toJson()));
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
