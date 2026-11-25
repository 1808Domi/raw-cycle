import 'package:flutter_test/flutter_test.dart';
import 'package:raw_cycle/features/cycle_tracking/data/models/cycle_entry.dart';
import 'package:raw_cycle/services/cycle_service.dart';

void main() {
  test('uses the default averages without recorded period days', () async {
    final service = CycleService(
      entriesProvider: () async => const [],
      clock: () => DateTime(2026, 12, 30),
    );

    expect(await service.getAverageCycleLength(), 28);
    expect(await service.getAveragePeriodLength(), 5);
    expect(await service.hasSufficientDataForPredictions(), isFalse);
    expect(await service.getCurrentCycleDay(), isNull);
    expect(await service.getCurrentCyclePhase(), CyclePhase.unknown);
    expect(await service.getNextPeriodDate(), isNull);
    expect(await service.getNextOvulationDate(), isNull);
    expect(await service.getPredictedPeriodDays(), isEmpty);
    expect(await service.getPredictedFertileDays(), isEmpty);
    expect(await service.getPredictedOvulationDay(), isEmpty);
    expect(await service.getDaysUntilNextPeriod(), isNull);
    expect(await service.getDaysUntilOvulation(), isNull);
  });

  test('calculates cycle estimates from historical period entries', () async {
    final service = CycleService(
      entriesProvider: () async => [
        ..._periodDays(DateTime(2026, 11, 1), 5),
        ..._periodDays(DateTime(2026, 11, 29), 5),
        ..._periodDays(DateTime(2026, 12, 27), 4),
      ],
      clock: () => DateTime(2026, 12, 30, 18),
    );

    expect(await service.getAverageCycleLength(), 28);
    expect(await service.getAveragePeriodLength(), 5);
    expect(await service.hasSufficientDataForPredictions(), isTrue);
    expect(await service.getCurrentCycleDay(), 4);
    expect(await service.getCurrentCyclePhase(), CyclePhase.menstruation);
    expect(await service.getNextPeriodDate(), DateTime(2027, 1, 24));
    expect(await service.getNextOvulationDate(), DateTime(2027, 1, 10));
    expect(await service.getPredictedPeriodDays(), [
      DateTime(2027, 1, 24),
      DateTime(2027, 1, 25),
      DateTime(2027, 1, 26),
      DateTime(2027, 1, 27),
      DateTime(2027, 1, 28),
    ]);
    expect(await service.getPredictedFertileDays(), [
      DateTime(2027, 1, 5),
      DateTime(2027, 1, 6),
      DateTime(2027, 1, 7),
      DateTime(2027, 1, 8),
      DateTime(2027, 1, 9),
      DateTime(2027, 1, 10),
      DateTime(2027, 1, 11),
    ]);
    expect(await service.getPredictedOvulationDay(), [DateTime(2027, 1, 10)]);
    expect(await service.getDaysUntilNextPeriod(), 25);
    expect(await service.getDaysUntilOvulation(), 11);
  });

  test('summarizes cycle history and optional daily observations', () async {
    final entries = [
      _entry(
        'period-1',
        DateTime(2026, 10, 1),
        isPeriodDay: true,
        symptoms: const ['Müdigkeit', 'Krämpfe', 'Müdigkeit'],
        mood: Mood.sehrGut,
        energyLevel: EnergyLevel.hoch,
      ),
      _entry('period-1-day-2', DateTime(2026, 10, 2), isPeriodDay: true),
      _entry('period-1-day-3', DateTime(2026, 10, 3), isPeriodDay: true),
      _entry(
        'observations-1',
        DateTime(2026, 10, 4),
        symptoms: const ['Müdigkeit', 'Kopfschmerzen'],
        mood: Mood.neutral,
        energyLevel: EnergyLevel.normal,
      ),
      ...List.generate(
        5,
        (index) => _entry(
          'period-2-$index',
          DateTime(2026, 10, 29 + index),
          isPeriodDay: true,
          symptoms: index == 0 ? const ['Krämpfe'] : const [],
          mood: index == 0 ? Mood.sehrGut : null,
          energyLevel: index == 0 ? EnergyLevel.niedrig : null,
        ),
      ),
      ...List.generate(
        5,
        (index) => _entry(
          'period-3-$index',
          DateTime(2026, 11, 26 + index),
          isPeriodDay: true,
        ),
      ),
    ];
    final service = CycleService(
      entriesProvider: () async => entries,
      clock: () => DateTime(2026, 12, 5),
    );

    final stats = await service.getStatistics();

    expect(stats.averageCycleLength, 28);
    expect(stats.shortestCycleLength, 28);
    expect(stats.longestCycleLength, 28);
    expect(stats.averagePeriodLength, 4);
    expect(stats.shortestPeriodLength, 3);
    expect(stats.longestPeriodLength, 5);
    expect(stats.entryCount, 14);
    expect(stats.recognizedCycleCount, 3);
    expect(stats.firstEntryDate, DateTime(2026, 10, 1));
    expect(
      stats.frequentSymptoms.map((item) => (item.name, item.count)).toList(),
      [('Krämpfe', 2), ('Müdigkeit', 2), ('Kopfschmerzen', 1)],
    );
    expect(stats.moodCounts[Mood.sehrGut], 2);
    expect(stats.moodCounts[Mood.neutral], 1);
    expect(stats.moodCounts[Mood.sehrSchlecht], 0);
    expect(stats.energyLevelCounts[EnergyLevel.hoch], 1);
    expect(stats.energyLevelCounts[EnergyLevel.normal], 1);
    expect(stats.energyLevelCounts[EnergyLevel.niedrig], 1);
  });

  test('statistics use empty values when no entries exist', () async {
    final service = CycleService(
      entriesProvider: () async => const [],
      clock: () => DateTime(2026, 12, 5),
    );

    final stats = await service.getStatistics();

    expect(stats.averageCycleLength, isNull);
    expect(stats.averagePeriodLength, isNull);
    expect(stats.frequentSymptoms, isEmpty);
    expect(stats.entryCount, 0);
    expect(stats.recognizedCycleCount, 0);
    expect(stats.firstEntryDate, isNull);
    expect(stats.moodCounts.values, everyElement(0));
    expect(stats.energyLevelCounts.values, everyElement(0));
  });

  test(
    'returns zero when the predicted period begins today regardless of time',
    () async {
      final service = CycleService(
        entriesProvider: () async => [
          ..._periodDays(DateTime(2026, 10, 1), 5),
          ..._periodDays(DateTime(2026, 10, 29), 5),
        ],
        clock: () => DateTime(2026, 11, 26, 23, 59),
      );

      expect(await service.getNextPeriodDate(), DateTime(2026, 11, 26));
      expect(await service.getDaysUntilNextPeriod(), 0);
    },
  );

  test(
    'estimates the next ovulation after the current one has passed',
    () async {
      final service = CycleService(
        entriesProvider: () async => [
          ..._periodDays(DateTime(2026, 10, 1), 5),
          ..._periodDays(DateTime(2026, 10, 29), 3),
        ],
        clock: () => DateTime(2026, 11, 17),
      );

      expect(await service.getCurrentCycleDay(), 20);
      expect(await service.getCurrentCyclePhase(), CyclePhase.luteal);
      expect(await service.getNextPeriodDate(), DateTime(2026, 11, 26));
      expect(await service.getNextOvulationDate(), DateTime(2026, 12, 10));
      expect(await service.getDaysUntilOvulation(), 23);
    },
  );

  test(
    'projects the current cycle day when a period has not been logged',
    () async {
      final service = CycleService(
        entriesProvider: () async => [
          ..._periodDays(DateTime(2026, 10, 1), 5),
          ..._periodDays(DateTime(2026, 10, 29), 3),
        ],
        clock: () => DateTime(2026, 11, 30),
      );

      expect(await service.getCurrentCycleDay(), 5);
      expect(await service.getCurrentCyclePhase(), CyclePhase.follicular);
      expect(await service.getNextPeriodDate(), DateTime(2026, 12, 24));
    },
  );

  test(
    'identifies fertile and ovulation days and describes the phase',
    () async {
      final entries = [
        ..._periodDays(DateTime(2026, 10, 1), 5),
        ..._periodDays(DateTime(2026, 10, 29), 5),
      ];
      final fertileService = CycleService(
        entriesProvider: () async => entries,
        clock: () => DateTime(2026, 11, 9),
      );
      final ovulationService = CycleService(
        entriesProvider: () async => entries,
        clock: () => DateTime(2026, 11, 12),
      );

      expect(await fertileService.getCurrentCyclePhase(), CyclePhase.fertile);
      expect(
        await fertileService.getPhaseDescription(),
        contains('fruchtbares Zeitfenster'),
      );
      expect(
        await ovulationService.getCurrentCyclePhase(),
        CyclePhase.ovulation,
      );
    },
  );
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

CycleEntry _entry(
  String id,
  DateTime date, {
  bool isPeriodDay = false,
  List<String> symptoms = const [],
  Mood? mood,
  EnergyLevel? energyLevel,
}) {
  return CycleEntry(
    id: id,
    date: date,
    isPeriodDay: isPeriodDay,
    symptoms: symptoms,
    mood: mood,
    energyLevel: energyLevel,
  );
}
