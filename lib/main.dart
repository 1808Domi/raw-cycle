import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'features/cycle_tracking/data/database_service.dart';
import 'features/onboarding/data/onboarding_service.dart';
import 'features/settings/data/settings_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeDateFormatting('de_DE');
    await Hive.initFlutter();
    DatabaseService.instance.registerAdapters();
    await DatabaseService.instance.init();
    await SettingsService.instance.init();
    await OnboardingService.instance.init();
    await NotificationService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('App initialization failed: $error\n$stackTrace');
    rethrow;
  }

  runApp(const RawCycleApp());
  NotificationService.instance.observeCycleEntryChanges();
  unawaited(_restoreNotificationSchedules());
}

Future<void> _restoreNotificationSchedules() async {
  try {
    final settings = await SettingsService.instance.load();
    await NotificationService.instance.syncWithSettings(settings);
  } catch (error, stackTrace) {
    debugPrint('Could not restore reminder schedules: $error\n$stackTrace');
  }
}
