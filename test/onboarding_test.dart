import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:raw_cycle/app.dart';
import 'package:raw_cycle/features/cycle_tracking/data/database_service.dart';
import 'package:raw_cycle/features/onboarding/data/onboarding_service.dart';
import 'package:raw_cycle/features/onboarding/presentation/onboarding_page.dart';
import 'package:raw_cycle/features/settings/data/settings_service.dart';

void main() {
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'raw_cycle_onboarding_',
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
    await Hive.box<bool>('raw_cycle_onboarding').clear();
  });

  testWidgets('shows four pages and completes from the final action', (
    WidgetTester tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPage(
          onComplete: () async {
            completed = true;
          },
        ),
      ),
    );

    expect(find.text('Willkommen'), findsOneWidget);
    for (final title in [
      'Intelligente Vorhersagen',
      'Datenschutz',
      "Los geht's",
    ]) {
      await tester.tap(find.text('Weiter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(title), findsOneWidget);
    }

    await tester.tap(find.text('Raw Cycle starten'));
    await tester.pump();
    expect(completed, isTrue);
  });

  testWidgets('skip completes onboarding', (WidgetTester tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPage(
          onComplete: () async {
            completed = true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Überspringen'));
    await tester.pump();
    expect(completed, isTrue);
  });

  test('completion status is stored locally', () async {
    expect(OnboardingService.instance.hasCompletedOnboarding, isFalse);
    await OnboardingService.instance.markCompleted();
    expect(OnboardingService.instance.hasCompletedOnboarding, isTrue);
  });

  testWidgets('the app skips onboarding after it has been completed', (
    WidgetTester tester,
  ) async {
    expect(OnboardingService.instance.hasCompletedOnboarding, isFalse);
    await tester.pumpWidget(const RawCycleApp());
    expect(find.text('Willkommen'), findsOneWidget);

    await tester.runAsync(OnboardingService.instance.markCompleted);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const RawCycleApp());
    await tester.pump();

    expect(find.text('Willkommen'), findsNothing);
    expect(find.text('Nächste Periode'), findsOneWidget);
  });
}
