import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:raw_cycle/app.dart';
import 'package:raw_cycle/features/calendar/presentation/calendar_page.dart';
import 'package:raw_cycle/features/cycle_tracking/data/database_service.dart';
import 'package:raw_cycle/features/onboarding/data/onboarding_service.dart';
import 'package:raw_cycle/features/settings/data/settings_service.dart';

void main() {
  late Directory settingsDirectory;
  final database = DatabaseService.instance;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
    settingsDirectory = await Directory.systemTemp.createTemp(
      'raw_cycle_widget_settings_',
    );
    Hive.init(settingsDirectory.path);
    database.registerAdapters();
    await database.init();
    await OnboardingService.instance.init();
    await SettingsService.instance.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await settingsDirectory.delete(recursive: true);
  });

  setUp(() async {
    await SettingsService.instance.save(const CycleSettings());
    await OnboardingService.instance.markCompleted();
  });

  testWidgets('dashboard has no entry action or saved-entry list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RawCycleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Letzte Einträge'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('shows all sections through bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RawCycleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final hour = DateTime.now().hour;
    final greeting = switch (hour) {
      < 12 => 'Guten Morgen',
      < 18 => 'Guten Tag',
      _ => 'Guten Abend',
    };
    expect(find.text(greeting), findsOneWidget);
    expect(find.text('Nächste Periode'), findsOneWidget);
    expect(find.text('Nächster Eisprung'), findsOneWidget);

    await tester.tap(find.text('Kalender').last);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarPage), findsOneWidget);

    await tester.tap(find.text('Statistik').last);
    await tester.pumpAndSettle();
    expect(find.text('Zyklusanalyse'), findsOneWidget);
    expect(find.text('Periodenanalyse'), findsOneWidget);
    expect(
      find.textContaining('Sobald du Zykluseinträge erfasst'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Datenbasis'), findsOneWidget);

    await tester.tap(find.text('Einstellungen').last);
    await tester.pumpAndSettle();
    expect(find.text('Standard Zykluslänge'), findsNothing);
    expect(find.text('Standard Periodendauer'), findsNothing);
    expect(find.text('Periodenerinnerung'), findsOneWidget);
    expect(find.text('Erinnerung aktivieren'), findsWidgets);
  });
}
