import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:raw_cycle/features/app_protection/data/pin_credential_service.dart';
import 'package:raw_cycle/features/settings/data/settings_service.dart';
import 'package:raw_cycle/features/settings/presentation/settings_page.dart';

void main() {
  late Directory settingsDirectory;
  final settings = SettingsService.instance;

  setUpAll(() async {
    settingsDirectory = await Directory.systemTemp.createTemp(
      'raw_cycle_settings_notifications_',
    );
    Hive.init(settingsDirectory.path);
    await settings.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await settingsDirectory.delete(recursive: true);
  });

  setUp(() async {
    await settings.save(const CycleSettings());
  });

  testWidgets('changing one reminder only syncs that reminder', (
    WidgetTester tester,
  ) async {
    final syncCalls = <(CycleSettings, bool, bool, bool)>[];
    CycleSettings? savedSettings;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            settingsSaver: (settings) async {
              savedSettings = settings;
            },
            reminderSettingsSynchronizer:
                (
                  settings, {
                  required bool syncDaily,
                  required bool syncPeriod,
                  required bool syncOvulation,
                }) async {
                  syncCalls.add((
                    settings,
                    syncDaily,
                    syncPeriod,
                    syncOvulation,
                  ));
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(syncCalls, hasLength(1));
    expect(savedSettings?.periodReminderEnabled, isTrue);
    expect(syncCalls.single.$1.periodReminderEnabled, isTrue);
    expect(syncCalls.single.$2, isFalse);
    expect(syncCalls.single.$3, isTrue);
    expect(syncCalls.single.$4, isFalse);
  });

  testWidgets('app protection options appear only when enabled and save', (
    WidgetTester tester,
  ) async {
    CycleSettings? savedSettings;
    final pinCredentials = _FakePinCredentialRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            settingsSaver: (settings) async {
              savedSettings = settings;
            },
            pinCredentialRepository: pinCredentials,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('App-Schutz aktivieren'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Authentifizierungsmethode'), findsNothing);
    await tester.tap(find.text('App-Schutz aktivieren'));
    await tester.pumpAndSettle();

    expect(find.text('Authentifizierungsmethode'), findsOneWidget);
    expect(find.text('Nur beim App-Start prüfen'), findsOneWidget);
    await tester.tap(find.text('Geräteentsperrung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PIN').last);
    await tester.pumpAndSettle();
    expect(find.text('PIN einrichten'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '1234');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tester.tap(find.text('PIN speichern'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nur beim App-Start prüfen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nach Inaktivität erneut prüfen').last);
    await tester.pumpAndSettle();

    expect(savedSettings?.appProtectionEnabled, isTrue);
    expect(savedSettings?.appProtectionMethod, AppProtectionMethod.pin);
    expect(pinCredentials.pin, '1234');
    expect(
      savedSettings?.appProtectionCheckMode,
      AppProtectionCheckMode.afterInactivity,
    );
  });
}

class _FakePinCredentialRepository implements PinCredentialRepository {
  String? pin;

  @override
  Future<bool> isPinConfigured() async => pin != null;

  @override
  Future<void> setPin(String pin) async {
    this.pin = pin;
  }

  @override
  Future<bool> verifyPin(String pin) async => this.pin == pin;
}
