import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raw_cycle/features/cycle_tracking/data/models/cycle_entry.dart';
import 'package:raw_cycle/features/dashboard/presentation/dashboard_page.dart';
import 'package:raw_cycle/services/cycle_service.dart';

void main() {
  testWidgets('staggered cards fade in and slide up on dashboard entry', (
    WidgetTester tester,
  ) async {
    final service = CycleService(
      entriesProvider: () async => const [],
      clock: () => DateTime(2026, 11, 24),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DashboardPage(cycleService: service)),
      ),
    );

    const cardKeys = [
      'period-card-entrance',
      'ovulation-card-entrance',
      'phase-card-entrance',
    ];
    for (final key in cardKeys) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }

    FadeTransition fadeFor(String key) {
      return tester.widget<FadeTransition>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(FadeTransition),
        ),
      );
    }

    SlideTransition slideFor(String key) {
      return tester.widget<SlideTransition>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(SlideTransition),
        ),
      );
    }

    await tester.pump(const Duration(milliseconds: 250));

    final fades = cardKeys.map(fadeFor).toList();
    expect(fades[0].opacity.value, greaterThan(fades[1].opacity.value));
    expect(fades[1].opacity.value, greaterThan(fades[2].opacity.value));

    final slides = cardKeys.map(slideFor).toList();
    expect(slides[0].position.value.dy, lessThan(0.12));
    expect(slides[2].position.value.dy, greaterThan(0));

    await tester.pumpAndSettle();
    for (final key in cardKeys) {
      expect(fadeFor(key).opacity.value, 1);
    }
  });

  testWidgets('shows the insufficient-data message without period history', (
    WidgetTester tester,
  ) async {
    final service = CycleService(
      entriesProvider: () async => const [],
      clock: () => DateTime(2026, 11, 24),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DashboardPage(cycleService: service)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nächste Periode'), findsOneWidget);
    expect(find.text('Nächster Eisprung'), findsOneWidget);
    expect(find.text('—'), findsNothing);
    expect(find.text('…'), findsNothing);
    expect(
      find.text('Für genaue Vorhersagen werden mehr Zyklusdaten benötigt.'),
      findsOneWidget,
    );
    expect(find.text('Noch nicht verfügbar'), findsOneWidget);
    expect(find.text('Letzte Einträge'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('shows countdowns and phase description', (
    WidgetTester tester,
  ) async {
    final service = CycleService(
      entriesProvider: () async => [
        ..._periodDays(DateTime(2026, 10, 1), 5),
        ..._periodDays(DateTime(2026, 10, 29), 5),
      ],
      clock: () => DateTime(2026, 11, 9),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DashboardPage(cycleService: service)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('17'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Tage'), findsNWidgets(2));
    expect(find.textContaining('%'), findsNothing);
    final indicators = tester
        .widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .toList();
    expect(indicators.map((indicator) => indicator.value), [12 / 28, 12 / 14]);
    expect(
      indicators.every(
        (indicator) => indicator.valueColor?.value == Colors.blue,
      ),
      isTrue,
    );
    expect(
      indicators.every((indicator) => indicator.backgroundColor != Colors.blue),
      isTrue,
    );
    expect(find.text('Fruchtbare Phase'), findsOneWidget);
    expect(
      find.text(
        'Dein fruchtbares Zeitfenster hat voraussichtlich begonnen. Der '
        'Eisprung wird in den kommenden Tagen erwartet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('animates progress rings from zero with easeInOutCubic', (
    WidgetTester tester,
  ) async {
    final service = CycleService(
      entriesProvider: () async => [
        ..._periodDays(DateTime(2026, 10, 1), 5),
        ..._periodDays(DateTime(2026, 10, 29), 5),
      ],
      clock: () => DateTime(2026, 11, 9),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DashboardPage(cycleService: service)),
      ),
    );
    await tester.pump();

    expect(find.text('17'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    List<double> ringValues() => tester
        .widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .map((indicator) => indicator.value!)
        .toList();

    expect(ringValues(), [0, 0]);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ringValues()[0], greaterThan(0));
    expect(ringValues()[0] / (12 / 28), lessThan(0.15));
    expect(ringValues()[1] / (12 / 14), lessThan(0.15));

    await tester.pump(const Duration(milliseconds: 300));
    expect(ringValues()[0] / (12 / 28), closeTo(0.5, 0.1));
    expect(ringValues()[1] / (12 / 14), closeTo(0.5, 0.1));

    await tester.pumpAndSettle();
    expect(ringValues(), [12 / 28, 12 / 14]);
  });

  testWidgets('restarts progress animation when dashboard becomes visible', (
    WidgetTester tester,
  ) async {
    final service = CycleService(
      entriesProvider: () async => [
        ..._periodDays(DateTime(2026, 10, 1), 5),
        ..._periodDays(DateTime(2026, 10, 29), 5),
      ],
      clock: () => DateTime(2026, 11, 9),
    );
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: selectedIndex == 0
                  ? DashboardPage(cycleService: service)
                  : const Center(child: Text('Andere Seite')),
              bottomNavigationBar: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    selectedIndex = index;
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'Übersicht',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    label: 'Kalender',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kalender').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Übersicht').last);
    await tester.pump();

    final initialValues = tester
        .widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .map((indicator) => indicator.value!)
        .toList();
    expect(initialValues, [0, 0]);

    await tester.pumpAndSettle();
    final finalValues = tester
        .widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .map((indicator) => indicator.value!)
        .toList();
    expect(finalValues, [12 / 28, 12 / 14]);
  });

  testWidgets('refreshes progress when cycle entries change', (
    WidgetTester tester,
  ) async {
    final changes = StreamController<void>.broadcast();
    addTearDown(changes.close);
    var entries = [
      ..._periodDays(DateTime(2026, 10, 1), 5),
      ..._periodDays(DateTime(2026, 10, 29), 5),
    ];
    final service = CycleService(
      entriesProvider: () async => entries,
      clock: () => DateTime(2026, 11, 9),
      changes: changes.stream,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DashboardPage(cycleService: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('17'), findsOneWidget);
    expect(find.text('43 %'), findsNothing);

    entries = [...entries, ..._periodDays(DateTime(2026, 11, 6), 1)];
    changes.add(null);
    await tester.pumpAndSettle();

    expect(find.text('15'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('22 %'), findsNothing);
    expect(find.text('75 %'), findsNothing);
  });

  testWidgets('shows zero days on the predicted period date', (
    WidgetTester tester,
  ) async {
    final service = CycleService(
      entriesProvider: () async => [
        ..._periodDays(DateTime(2026, 11, 1), 5),
        ..._periodDays(DateTime(2026, 11, 29), 5),
      ],
      clock: () => DateTime(2026, 12, 27, 23, 59),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DashboardPage(cycleService: service)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
    expect(find.text('Tage'), findsNWidgets(2));
    final indicators = tester
        .widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .toList();
    expect(indicators.first.value, 1);
  });

  testWidgets('fills the ovulation ring when no days remain', (
    WidgetTester tester,
  ) async {
    final service = CycleService(
      entriesProvider: () async => [
        ..._periodDays(DateTime(2026, 10, 1), 5),
        ..._periodDays(DateTime(2026, 10, 29), 5),
      ],
      clock: () => DateTime(2026, 11, 12),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DashboardPage(cycleService: service)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
    final indicators = tester
        .widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .toList();
    expect(indicators[1].value, 1);
  });

  testWidgets('clamps countdown progress values to the indicator range', (
    WidgetTester tester,
  ) async {
    final service = CycleService(
      entriesProvider: () async => [
        ..._periodDays(DateTime(2026, 10, 1), 3),
        ..._periodDays(DateTime(2026, 10, 9), 3),
      ],
      clock: () => DateTime(2026, 10, 20),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DashboardPage(cycleService: service)),
      ),
    );
    await tester.pumpAndSettle();

    final values = tester
        .widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .map((indicator) => indicator.value!)
        .toList();
    expect(values, [0.5, 1.0]);
    expect(values.every((value) => value >= 0 && value <= 1), isTrue);
  });
}

List<CycleEntry> _periodDays(DateTime start, int length) {
  return List.generate(
    length,
    (index) => CycleEntry(
      id: '${start.toIso8601String()}-$index',
      date: DateTime(start.year, start.month, start.day + index),
      isPeriodDay: true,
      bleedingIntensity: BleedingIntensity.mittel,
      symptoms: const [],
    ),
  );
}
