import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:raw_cycle/features/calendar/presentation/calendar_page.dart';
import 'package:raw_cycle/features/cycle_tracking/data/models/cycle_entry.dart';
import 'package:raw_cycle/services/cycle_service.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  testWidgets('selects a day and allows changing the visible month', (
    WidgetTester tester,
  ) async {
    final initialDate = DateTime(2026, 11, 24);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(
            initialDate: initialDate,
            entriesFuture: Future.value(const <CycleEntry>[]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('November 2026'), findsOneWidget);

    await tester.tap(find.text('25').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        DateFormat(
          'EEEE, d. MMMM yyyy',
          'de_DE',
        ).format(DateTime(2026, 11, 25)),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Für diesen Tag existiert noch kein Eintrag.'),
      findsOneWidget,
    );
    expect(find.text('Eintrag erstellen'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Dezember 2026'), findsOneWidget);

    final calendar = tester.widget<TableCalendar<CycleEntry>>(
      find.byType(TableCalendar<CycleEntry>),
    );
    expect(calendar.calendarFormat, CalendarFormat.month);
    expect(calendar.selectedDayPredicate?.call(DateTime(2026, 11, 25)), isTrue);
  });

  testWidgets('marks period, temperature, and normal entry days', (
    WidgetTester tester,
  ) async {
    final entries = [
      CycleEntry(
        id: 'period-with-temperature',
        date: DateTime(2026, 11, 25),
        isPeriodDay: true,
        bleedingIntensity: BleedingIntensity.mittel,
        temperature: 36.8,
        symptoms: const ['Kopfschmerzen'],
        notes: 'Testnotiz',
      ),
      CycleEntry(
        id: 'temperature-only',
        date: DateTime(2026, 11, 26),
        isPeriodDay: false,
        bleedingIntensity: BleedingIntensity.leicht,
        temperature: 36.7,
        symptoms: const [],
      ),
      CycleEntry(
        id: 'normal-entry',
        date: DateTime(2026, 11, 27),
        isPeriodDay: false,
        bleedingIntensity: BleedingIntensity.leicht,
        symptoms: const [],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(
            initialDate: DateTime(2026, 11, 25),
            entriesFuture: Future.value(entries),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calendar-marker-red')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-marker-blue')),
      findsNWidgets(2),
    );
    expect(find.byKey(const ValueKey('calendar-marker-gray')), findsOneWidget);

    final calendar = tester.widget<TableCalendar<CycleEntry>>(
      find.byType(TableCalendar<CycleEntry>),
    );
    expect(calendar.eventLoader!(DateTime(2026, 11, 25)), [entries[0]]);
    expect(find.text('Periode'), findsNWidgets(2));
    expect(find.text('Ja'), findsOneWidget);
    expect(find.text('Mittel'), findsOneWidget);
    expect(find.text('36.8 °C'), findsOneWidget);
    expect(find.text('Kopfschmerzen'), findsOneWidget);
    expect(find.text('Testnotiz'), findsOneWidget);
    expect(find.text('Eintrag bearbeiten'), findsOneWidget);
  });

  testWidgets('shows forecast markers and overlapping entry markers', (
    WidgetTester tester,
  ) async {
    final history = [
      ..._periodDays(DateTime(2026, 10, 1), 5),
      ..._periodDays(DateTime(2026, 10, 29), 5),
    ];
    final entries = [
      CycleEntry(
        id: 'normal-fertile-day',
        date: DateTime(2026, 11, 10),
        isPeriodDay: false,
        symptoms: const [],
      ),
      CycleEntry(
        id: 'temperature-fertile-day',
        date: DateTime(2026, 11, 11),
        isPeriodDay: false,
        temperature: 36.8,
        symptoms: const [],
      ),
      CycleEntry(
        id: 'normal-ovulation-day',
        date: DateTime(2026, 11, 12),
        isPeriodDay: false,
        symptoms: const [],
      ),
      CycleEntry(
        id: 'period-and-temperature',
        date: DateTime(2026, 11, 26),
        isPeriodDay: true,
        bleedingIntensity: BleedingIntensity.mittel,
        temperature: 36.9,
        symptoms: const [],
      ),
    ];
    final service = CycleService(
      entriesProvider: () async => [...history, ...entries],
      clock: () => DateTime(2026, 11, 9),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(
            initialDate: DateTime(2026, 11, 9),
            entriesFuture: Future.value(entries),
            cycleService: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calendar-marker-red')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-marker-orange')),
      findsNWidgets(5),
    );
    expect(
      find.byKey(const ValueKey('calendar-marker-green')),
      findsNWidgets(7),
    );
    expect(
      find.byKey(const ValueKey('calendar-marker-purple')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-marker-blue')),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const ValueKey('calendar-marker-gray')),
      findsNWidgets(2),
    );
    expect(find.text('Periode'), findsOneWidget);
    expect(find.text('Erwartete Periode'), findsOneWidget);
    expect(find.text('Fruchtbare Tage'), findsOneWidget);
    expect(find.text('Eisprung'), findsOneWidget);
    expect(find.text('Temperaturdaten'), findsOneWidget);
    expect(find.byType(Chip), findsNWidgets(6));
  });

  testWidgets('opens the entry dialog for the selected calendar day', (
    WidgetTester tester,
  ) async {
    final selectedDate = DateTime(2026, 11, 25);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(
            initialDate: selectedDate,
            entriesFuture: Future.value(const <CycleEntry>[]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final createButton = find.text('Eintrag erstellen');
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.text('Neuer Zykluseintrag'), findsOneWidget);
    expect(
      find.text(
        MaterialLocalizations.of(
          tester.element(find.text('Neuer Zykluseintrag')),
        ).formatMediumDate(selectedDate),
      ),
      findsOneWidget,
    );
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
