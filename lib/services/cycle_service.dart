import 'package:flutter/material.dart' show DateUtils;

import '../features/cycle_tracking/data/database_service.dart';
import '../features/cycle_tracking/data/models/cycle_entry.dart';

/// The estimated phase of the current cycle.
enum CyclePhase {
  /// No period start has been recorded to establish a cycle.
  unknown,

  /// The current cycle day falls within the average period length.
  menstruation,

  /// The estimated fertile window has not yet begun.
  follicular,

  /// The estimated fertile window, up to five days before ovulation.
  fertile,

  /// The estimated ovulation date is today.
  ovulation,

  /// The estimated ovulation date has passed.
  luteal,
}

/// Calculates cycle estimates from locally stored period-day entries.
///
/// Cycle starts are the first recorded period day after a gap of at least one
/// calendar day. Averages use completed recorded periods and intervals between
/// recorded cycle starts. The service uses a 28-day cycle and a 5-day period
/// until enough respective history is available.
class CycleService {
  CycleService({
    Future<List<CycleEntry>> Function()? entriesProvider,
    DateTime Function()? clock,
    Stream<void>? changes,
  }) : _entriesProvider =
           entriesProvider ?? DatabaseService.instance.getAllCycleEntries,
       _clock = clock ?? DateTime.now,
       _changes = changes,
       _usesDatabaseChanges = entriesProvider == null && changes == null;

  /// Shared service that reads entries from [DatabaseService].
  static final CycleService instance = CycleService();

  static const int defaultCycleLength = 28;
  static const int defaultPeriodLength = 5;
  static const int _lutealPhaseLength = 14;
  static const int _fertileWindowDays = 5;
  static const int _fertileDaysAfterOvulation = 1;

  final Future<List<CycleEntry>> Function() _entriesProvider;
  final DateTime Function() _clock;
  final Stream<void>? _changes;
  final bool _usesDatabaseChanges;

  /// Emits whenever a saved cycle entry changes, if a change stream is
  /// available for this service.
  Stream<void>? get entryChanges {
    if (_changes != null) {
      return _changes;
    }
    if (_usesDatabaseChanges && DatabaseService.instance.isInitialized) {
      return DatabaseService.instance.watchCycleEntryChanges();
    }
    return null;
  }

  /// Returns the rounded mean of intervals between recorded period starts.
  ///
  /// If fewer than two distinct starts are available, returns 28 days.
  Future<int> getAverageCycleLength() async {
    final data = await _loadCycleData();
    return data.averageCycleLength;
  }

  /// Returns the rounded mean of completed recorded period lengths.
  ///
  /// A period is a run of consecutive calendar days. An episode that includes
  /// today is considered ongoing and excluded from the average. If no completed
  /// episode is available, returns 5 days.
  Future<int> getAveragePeriodLength() async {
    final data = await _loadCycleData();
    return data.averagePeriodLength;
  }

  /// Whether recorded history exists for both cycle and period averages.
  ///
  /// This requires at least two period starts and one completed period episode.
  Future<bool> hasSufficientDataForPredictions() async {
    final data = await _loadCycleData();
    return data.hasSufficientData;
  }

  /// Returns the estimated current cycle day, or `null` if no start is recorded.
  ///
  /// The first period day is cycle day 1. If the last recorded start is more
  /// than one average cycle ago, the cycle day is projected using that average.
  Future<int?> getCurrentCycleDay() async {
    final data = await _loadCycleData();
    final currentStart = _currentCycleStart(data);
    if (currentStart == null) {
      return null;
    }

    return _daysBetween(currentStart, _today) + 1;
  }

  /// Estimates the current phase from the latest period start and cycle
  /// averages. Returns [CyclePhase.unknown] if no period start is recorded.
  ///
  /// Ovulation is estimated 14 days before the next period. The estimated
  /// ovulation day itself is classified as [CyclePhase.ovulation].
  Future<CyclePhase> getCurrentCyclePhase() async {
    final data = await _loadCycleData();
    return _currentCyclePhase(data);
  }

  /// Returns a user-friendly description of the currently estimated phase.
  ///
  /// If no period start has been recorded, the description explains that more
  /// cycle data is needed before a phase can be estimated.
  Future<String> getPhaseDescription() async {
    final data = await _loadCycleData();
    return switch (_currentCyclePhase(data)) {
      CyclePhase.unknown =>
        'Trage einen Periodentag ein, damit Raw Cycle deine Zyklusphase '
            'einschätzen kann.',
      CyclePhase.menstruation =>
        'Du befindest dich voraussichtlich in deiner Menstruation. Gönn dir '
            'die Ruhe, die dir guttut.',
      CyclePhase.follicular =>
        'In der Follikelphase reift eine Eizelle heran. Deine Energie kann '
            'in dieser Zeit wieder zunehmen.',
      CyclePhase.fertile =>
        'Dein fruchtbares Zeitfenster hat voraussichtlich begonnen. Der '
            'Eisprung wird in den kommenden Tagen erwartet.',
      CyclePhase.ovulation =>
        'Der Eisprung wird für heute erwartet. Die Schätzung basiert auf '
            'deinen bisherigen Zyklusdaten.',
      CyclePhase.luteal =>
        'Nach dem geschätzten Eisprung bereitet sich dein Körper auf die '
            'nächste Periode vor.',
    };
  }

  CyclePhase _currentCyclePhase(_CycleData data) {
    final currentStart = _currentCycleStart(data);
    if (currentStart == null) {
      return CyclePhase.unknown;
    }

    final cycleDay = _daysBetween(currentStart, _today) + 1;
    if (cycleDay <= data.averagePeriodLength) {
      return CyclePhase.menstruation;
    }

    final ovulationDate = _addCalendarDays(
      currentStart,
      data.averageCycleLength > _lutealPhaseLength
          ? data.averageCycleLength - _lutealPhaseLength
          : 0,
    );
    final comparison = _compareCalendarDays(_today, ovulationDate);
    if (comparison == 0) {
      return CyclePhase.ovulation;
    }
    if (comparison > 0) {
      return CyclePhase.luteal;
    }

    final fertileStart = _addCalendarDays(ovulationDate, -_fertileWindowDays);
    if (_compareCalendarDays(_today, fertileStart) >= 0) {
      return CyclePhase.fertile;
    }

    return CyclePhase.follicular;
  }

  /// Estimates the next period start, or `null` if no period start is recorded.
  ///
  /// The average cycle length is projected forward from the latest recorded
  /// period start. The result is today or a future calendar date.
  Future<DateTime?> getNextPeriodDate() async {
    final data = await _loadCycleData();
    return _nextPeriodDate(data);
  }

  /// Estimates the next ovulation date, or `null` without a recorded cycle.
  ///
  /// Ovulation is estimated 14 days before a predicted period. If that estimate
  /// has passed, the date is projected forward by whole average cycle lengths.
  Future<DateTime?> getNextOvulationDate() async {
    final data = await _loadCycleData();
    return _nextOvulationDate(data);
  }

  /// Returns the predicted calendar days of the next period.
  ///
  /// The list starts on the predicted period date and spans the average period
  /// length. Returns an empty list if no period start is recorded.
  Future<List<DateTime>> getPredictedPeriodDays() async {
    final data = await _loadCycleData();
    final nextPeriod = _nextPeriodDate(data);
    if (nextPeriod == null) {
      return const [];
    }

    return List.generate(
      data.averagePeriodLength,
      (index) => _addCalendarDays(nextPeriod, index),
      growable: false,
    );
  }

  /// Returns the predicted fertile window: five days before ovulation through
  /// one day after. Returns an empty list if no period start is recorded.
  Future<List<DateTime>> getPredictedFertileDays() async {
    final data = await _loadCycleData();
    final ovulationDay = _nextOvulationDate(data);
    if (ovulationDay == null) {
      return const [];
    }

    final fertileDaysCount =
        _fertileWindowDays + _fertileDaysAfterOvulation + 1;
    return List.generate(
      fertileDaysCount,
      (index) => _addCalendarDays(ovulationDay, index - _fertileWindowDays),
      growable: false,
    );
  }

  /// Returns the predicted next ovulation day as a one-item list.
  ///
  /// Returns an empty list if no period start is recorded.
  Future<List<DateTime>> getPredictedOvulationDay() async {
    final data = await _loadCycleData();
    final ovulationDay = _nextOvulationDate(data);
    return ovulationDay == null ? const [] : [ovulationDay];
  }

  /// Returns calendar days until the next estimated period, or `null` without
  /// a recorded cycle start.
  Future<int?> getDaysUntilNextPeriod() async {
    final data = await _loadCycleData();
    final nextPeriod = _nextPeriodDate(data);
    if (nextPeriod == null) {
      return null;
    }

    return _daysBetween(
      DateUtils.dateOnly(_clock()),
      DateUtils.dateOnly(nextPeriod),
    );
  }

  /// Returns calendar days until estimated ovulation, or `null` without a
  /// recorded cycle start.
  Future<int?> getDaysUntilOvulation() async {
    final data = await _loadCycleData();
    final ovulationDate = _nextOvulationDate(data);
    return ovulationDate == null ? null : _daysBetween(_today, ovulationDate);
  }

  /// Summarizes observed cycle lengths and optional daily observations.
  ///
  /// Cycle lengths use intervals between recorded period starts. Period
  /// lengths include completed runs only. Averages are `null` when no
  /// corresponding observations have been recorded.
  Future<CycleStatistics> getStatistics() async {
    final data = await _loadCycleData();
    final symptomCounts = <String, int>{};
    for (final entry in data.entries) {
      for (final symptom
          in entry.symptoms
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()) {
        symptomCounts.update(symptom, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    final frequentSymptoms =
        symptomCounts.entries
            .map(
              (entry) => SymptomFrequency(name: entry.key, count: entry.value),
            )
            .toList()
          ..sort((first, second) {
            final countComparison = second.count.compareTo(first.count);
            return countComparison != 0
                ? countComparison
                : first.name.compareTo(second.name);
          });

    final moodCounts = {
      for (final mood in Mood.values)
        mood: data.entries.where((entry) => entry.mood == mood).length,
    };
    final energyLevelCounts = {
      for (final energy in EnergyLevel.values)
        energy: data.entries
            .where((entry) => entry.energyLevel == energy)
            .length,
    };
    final sortedEntries = data.entries.toList()
      ..sort((first, second) => first.date.compareTo(second.date));

    return CycleStatistics(
      averageCycleLength: data.cycleLengths.isEmpty
          ? null
          : _roundedAverage(data.cycleLengths),
      shortestCycleLength: data.cycleLengths.isEmpty
          ? null
          : data.cycleLengths.reduce((a, b) => a < b ? a : b),
      longestCycleLength: data.cycleLengths.isEmpty
          ? null
          : data.cycleLengths.reduce((a, b) => a > b ? a : b),
      averagePeriodLength: data.periodLengths.isEmpty
          ? null
          : _roundedAverage(data.periodLengths),
      shortestPeriodLength: data.periodLengths.isEmpty
          ? null
          : data.periodLengths.reduce((a, b) => a < b ? a : b),
      longestPeriodLength: data.periodLengths.isEmpty
          ? null
          : data.periodLengths.reduce((a, b) => a > b ? a : b),
      frequentSymptoms: frequentSymptoms.take(5).toList(growable: false),
      moodCounts: moodCounts,
      energyLevelCounts: energyLevelCounts,
      entryCount: data.entries.length,
      recognizedCycleCount: data.cycleStarts.length,
      firstEntryDate: sortedEntries.isEmpty ? null : sortedEntries.first.date,
    );
  }

  Future<_CycleData> _loadCycleData() async {
    final today = _today;
    final entries = await _entriesProvider();
    final periodDays =
        entries
            .where((entry) => entry.isPeriodDay)
            .map((entry) => _calendarDate(entry.date))
            .where((date) => _compareCalendarDays(date, today) <= 0)
            .toSet()
            .toList()
          ..sort();

    final starts = <DateTime>[];
    final periodLengths = <int>[];
    DateTime? previousDay;
    var currentPeriodLength = 0;
    DateTime? currentPeriodEnd;

    for (final day in periodDays) {
      if (previousDay == null || _daysBetween(previousDay, day) > 1) {
        if (currentPeriodLength > 0 &&
            _compareCalendarDays(currentPeriodEnd!, today) < 0) {
          periodLengths.add(currentPeriodLength);
        }
        starts.add(day);
        currentPeriodLength = 1;
      } else {
        currentPeriodLength++;
      }

      previousDay = day;
      currentPeriodEnd = day;
    }

    if (currentPeriodLength > 0 &&
        _compareCalendarDays(currentPeriodEnd!, today) < 0) {
      periodLengths.add(currentPeriodLength);
    }

    final cycleLengths = <int>[
      for (var index = 1; index < starts.length; index++)
        _daysBetween(starts[index - 1], starts[index]),
    ];

    return _CycleData(
      entries: entries,
      cycleStarts: starts,
      cycleLengths: cycleLengths,
      periodLengths: periodLengths,
      hasCycleLengthHistory: cycleLengths.isNotEmpty,
      hasPeriodLengthHistory: periodLengths.isNotEmpty,
      averageCycleLength: cycleLengths.isEmpty
          ? defaultCycleLength
          : _roundedAverage(cycleLengths),
      averagePeriodLength: periodLengths.isEmpty
          ? defaultPeriodLength
          : _roundedAverage(periodLengths),
    );
  }

  DateTime? _nextPeriodDate(_CycleData data) {
    final lastStart = data.latestCycleStart;
    if (lastStart == null) {
      return null;
    }

    final elapsedDays = _daysBetween(lastStart, _today);
    final estimatedCyclesAhead = (elapsedDays / data.averageCycleLength).ceil();
    final cyclesAhead = estimatedCyclesAhead < 1 ? 1 : estimatedCyclesAhead;
    return _addCalendarDays(lastStart, cyclesAhead * data.averageCycleLength);
  }

  DateTime? _currentCycleStart(_CycleData data) {
    final lastStart = data.latestCycleStart;
    if (lastStart == null) {
      return null;
    }

    final elapsedDays = _daysBetween(lastStart, _today);
    final completedCycles = elapsedDays ~/ data.averageCycleLength;
    return _addCalendarDays(
      lastStart,
      completedCycles * data.averageCycleLength,
    );
  }

  DateTime? _nextOvulationDate(_CycleData data) {
    final nextPeriod = _nextPeriodDate(data);
    if (nextPeriod == null) {
      return null;
    }

    var ovulationDate = _addCalendarDays(nextPeriod, -_lutealPhaseLength);
    while (_compareCalendarDays(ovulationDate, _today) < 0) {
      ovulationDate = _addCalendarDays(ovulationDate, data.averageCycleLength);
    }
    return ovulationDate;
  }

  DateTime get _today => _calendarDate(_clock());

  static int _roundedAverage(List<int> values) {
    return (values.reduce((sum, value) => sum + value) / values.length).round();
  }

  static DateTime _calendarDate(DateTime date) {
    return DateUtils.dateOnly(date);
  }

  static DateTime _addCalendarDays(DateTime date, int days) {
    return DateTime(date.year, date.month, date.day + days);
  }

  static int _daysBetween(DateTime start, DateTime end) {
    final startUtc = DateTime.utc(start.year, start.month, start.day);
    final endUtc = DateTime.utc(end.year, end.month, end.day);
    return endUtc.difference(startUtc).inDays;
  }

  static int _compareCalendarDays(DateTime first, DateTime second) {
    return _daysBetween(second, first);
  }
}

class CycleStatistics {
  CycleStatistics({
    required this.averageCycleLength,
    required this.shortestCycleLength,
    required this.longestCycleLength,
    required this.averagePeriodLength,
    required this.shortestPeriodLength,
    required this.longestPeriodLength,
    required List<SymptomFrequency> frequentSymptoms,
    required Map<Mood, int> moodCounts,
    required Map<EnergyLevel, int> energyLevelCounts,
    required this.entryCount,
    required this.recognizedCycleCount,
    required this.firstEntryDate,
  }) : frequentSymptoms = List.unmodifiable(frequentSymptoms),
       moodCounts = Map.unmodifiable(moodCounts),
       energyLevelCounts = Map.unmodifiable(energyLevelCounts);

  final int? averageCycleLength;
  final int? shortestCycleLength;
  final int? longestCycleLength;
  final int? averagePeriodLength;
  final int? shortestPeriodLength;
  final int? longestPeriodLength;
  final List<SymptomFrequency> frequentSymptoms;
  final Map<Mood, int> moodCounts;
  final Map<EnergyLevel, int> energyLevelCounts;
  final int entryCount;
  final int recognizedCycleCount;
  final DateTime? firstEntryDate;
}

class SymptomFrequency {
  const SymptomFrequency({required this.name, required this.count});

  final String name;
  final int count;
}

class _CycleData {
  const _CycleData({
    required this.entries,
    required this.cycleStarts,
    required this.cycleLengths,
    required this.periodLengths,
    required this.hasCycleLengthHistory,
    required this.hasPeriodLengthHistory,
    required this.averageCycleLength,
    required this.averagePeriodLength,
  });

  final List<CycleEntry> entries;
  final List<DateTime> cycleStarts;
  final List<int> cycleLengths;
  final List<int> periodLengths;
  final bool hasCycleLengthHistory;
  final bool hasPeriodLengthHistory;
  final int averageCycleLength;
  final int averagePeriodLength;

  bool get hasSufficientData => hasCycleLengthHistory && hasPeriodLengthHistory;

  DateTime? get latestCycleStart =>
      cycleStarts.isEmpty ? null : cycleStarts.last;
}
