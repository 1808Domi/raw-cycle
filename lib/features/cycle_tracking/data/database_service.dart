import 'dart:async';

import 'package:hive_ce/hive.dart';

import 'models/cycle_entry.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();
  static const _cycleEntriesBoxName = 'cycle_entries';

  Future<void>? _initialization;
  Future<void> _writeQueue = Future<void>.value();
  Box<CycleEntry>? _cycleEntriesBox;

  void registerAdapters() {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(BleedingIntensityAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(CervicalMucusAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(MoodAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(EnergyLevelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CycleEntryAdapter());
    }
  }

  Future<void> init() {
    return _initialization ??= _openBox();
  }

  Future<void> _openBox() async {
    registerAdapters();
    _cycleEntriesBox = await Hive.openBox<CycleEntry>(_cycleEntriesBoxName);
  }

  Box<CycleEntry> get _box {
    final box = _cycleEntriesBox;
    if (box == null || !box.isOpen) {
      throw StateError('DatabaseService.init() must be called before use.');
    }
    return box;
  }

  Future<void> saveCycleEntry(CycleEntry entry) {
    return _enqueueWrite(() => _saveCycleEntry(entry));
  }

  Future<void> _saveCycleEntry(CycleEntry entry) async {
    final entriesForDate = _box.values
        .where((existing) => _isSameCalendarDay(existing.date, entry.date))
        .toList();

    if (entriesForDate.isEmpty) {
      await _box.put(entry.id, entry);
      return;
    }

    final existingEntry = entriesForDate.firstWhere(
      (existing) => existing.id == entry.id,
      orElse: () => entriesForDate.first,
    );
    final entryToSave = existingEntry.id == entry.id
        ? entry
        : CycleEntry(
            id: existingEntry.id,
            date: entry.date,
            isPeriodDay: entry.isPeriodDay,
            bleedingIntensity: entry.bleedingIntensity,
            temperature: entry.temperature,
            symptoms: entry.symptoms,
            notes: entry.notes,
            cervicalMucus: entry.cervicalMucus,
            mood: entry.mood,
            energyLevel: entry.energyLevel,
            sleepHours: entry.sleepHours,
          );

    await _box.put(entryToSave.id, entryToSave);

    final duplicateIds = entriesForDate
        .where((existing) => existing.id != entryToSave.id)
        .map((existing) => existing.id)
        .toList();
    await _box.deleteAll(duplicateIds);
  }

  Future<List<CycleEntry>> getAllCycleEntries() async {
    return _box.values.toList(growable: false);
  }

  Future<void> replaceAllCycleEntries(List<CycleEntry> entries) {
    return _enqueueWrite(() async {
      final ids = <String>{};
      final dates = <String>{};
      for (final entry in entries) {
        final dateKey =
            '${entry.date.year}-${entry.date.month}-${entry.date.day}';
        if (!ids.add(entry.id)) {
          throw FormatException('Duplicate cycle entry id: ${entry.id}');
        }
        if (!dates.add(dateKey)) {
          throw FormatException('More than one cycle entry for $dateKey.');
        }
      }

      await _box.clear();
      await _box.putAll({for (final entry in entries) entry.id: entry});
    });
  }

  bool get isInitialized => _cycleEntriesBox?.isOpen ?? false;

  Stream<void> watchCycleEntryChanges() {
    return _box.watch().map<void>((_) {});
  }

  Future<CycleEntry?> getEntryByDate(DateTime date) async {
    for (final entry in _box.values) {
      if (_isSameCalendarDay(entry.date, date)) {
        return entry;
      }
    }
    return null;
  }

  Future<void> updateCycleEntry(CycleEntry entry) {
    return _enqueueWrite(() async {
      final previousEntry = _box.get(entry.id);
      await _saveCycleEntry(entry);

      if (previousEntry != null &&
          !_isSameCalendarDay(previousEntry.date, entry.date)) {
        final savedEntry = await getEntryByDate(entry.date);
        if (savedEntry?.id != entry.id) {
          await _box.delete(entry.id);
        }
      }
    });
  }

  Future<void> deleteCycleEntry(String id) {
    return _enqueueWrite(() => _box.delete(id));
  }

  bool _isSameCalendarDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Future<void> _enqueueWrite(Future<void> Function() operation) {
    final completer = Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await operation();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
