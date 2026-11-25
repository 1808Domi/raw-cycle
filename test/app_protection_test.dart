import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:raw_cycle/app.dart';
import 'package:raw_cycle/features/app_protection/data/pin_credential_service.dart';
import 'package:raw_cycle/features/app_protection/presentation/app_lock_page.dart';
import 'package:raw_cycle/features/cycle_tracking/data/database_service.dart';
import 'package:raw_cycle/features/onboarding/data/onboarding_service.dart';
import 'package:raw_cycle/features/settings/data/settings_service.dart';

void main() {
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'raw_cycle_app_protection_',
    );
    Hive.init(storageDirectory.path);
    DatabaseService.instance.registerAdapters();
    await DatabaseService.instance.init();
    await SettingsService.instance.init();
    await OnboardingService.instance.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await storageDirectory.delete(recursive: true);
  });

  setUp(() async {
    await OnboardingService.instance.markCompleted();
    await SettingsService.instance.save(
      const CycleSettings(
        appProtectionEnabled: true,
        appProtectionMethod: AppProtectionMethod.deviceUnlock,
      ),
    );
  });

  testWidgets('keeps the lock screen open after authentication is cancelled', (
    WidgetTester tester,
  ) async {
    var authenticated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockPage(
          settings: const CycleSettings(
            appProtectionEnabled: true,
            appProtectionMethod: AppProtectionMethod.deviceUnlock,
          ),
          authenticate: (_) async => false,
          onAuthenticated: () => authenticated = true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Raw Cycle entsperren'), findsOneWidget);
    expect(
      find.textContaining('Authentifizierung abgebrochen'),
      findsOneWidget,
    );
    expect(authenticated, isFalse);
  });

  testWidgets('opens the dashboard only after successful authentication', (
    WidgetTester tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      RawCycleApp(
        authenticator: (_) async {
          attempts++;
          return true;
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(attempts, 1);
    expect(find.text('Raw Cycle entsperren'), findsNothing);
    expect(find.text('Nächste Periode'), findsOneWidget);
  });

  testWidgets('relocks after the app is backgrounded in inactivity mode', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(
      () => SettingsService.instance.save(
        const CycleSettings(
          appProtectionEnabled: true,
          appProtectionMethod: AppProtectionMethod.deviceUnlock,
          appProtectionCheckMode: AppProtectionCheckMode.afterInactivity,
        ),
      ),
    );

    var attempts = 0;
    await tester.pumpWidget(
      RawCycleApp(
        authenticator: (_) async {
          attempts++;
          return true;
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(attempts, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('Raw Cycle entsperren'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(attempts, 2);
    expect(find.text('Nächste Periode'), findsOneWidget);
  });

  testWidgets(
    'accepts a configured PIN and keeps incorrect PIN attempts locked',
    (WidgetTester tester) async {
      final credentials = _FakePinCredentialRepository('4826');
      var authenticated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AppLockPage(
            settings: const CycleSettings(
              appProtectionEnabled: true,
              appProtectionMethod: AppProtectionMethod.pin,
            ),
            pinCredentials: credentials,
            onAuthenticated: () => authenticated = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Entsperren'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(authenticated, isFalse);
      expect(find.text('Die PIN ist nicht korrekt.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '4826');
      await tester.tap(find.text('Entsperren'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(authenticated, isTrue);
    },
  );

  testWidgets('sets a PIN if imported settings have no local PIN credential', (
    WidgetTester tester,
  ) async {
    final credentials = _FakePinCredentialRepository(null);
    var authenticated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockPage(
          settings: const CycleSettings(
            appProtectionEnabled: true,
            appProtectionMethod: AppProtectionMethod.pin,
          ),
          pinCredentials: credentials,
          onAuthenticated: () => authenticated = true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PIN einrichten'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).at(0), '5824');
    await tester.enterText(find.byType(TextField).at(1), '5824');
    await tester.tap(find.text('PIN einrichten').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(credentials.pin, '5824');
    expect(authenticated, isTrue);
  });
}

class _FakePinCredentialRepository implements PinCredentialRepository {
  _FakePinCredentialRepository(this.pin);

  String? pin;

  @override
  Future<bool> isPinConfigured() async => pin != null;

  @override
  Future<void> setPin(String pin) async {
    this.pin = pin;
  }

  @override
  Future<bool> verifyPin(String candidate) async => candidate == pin;
}
