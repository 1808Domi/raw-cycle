import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:raw_cycle/features/cycle_tracking/data/database_service.dart';
import 'package:raw_cycle/features/cycle_tracking/data/models/cycle_entry.dart';

void main() {
  late Directory databaseDirectory;
  final database = DatabaseService.instance;

  setUpAll(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'raw_cycle_hive_',
    );
    Hive.init(databaseDirectory.path);
    await database.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await databaseDirectory.delete(recursive: true);
  });

  test('creates, reads, updates, and deletes cycle entries', () async {
    final entry = CycleEntry(
      id: 'test-entry',
      date: DateTime.utc(2026, 11, 24),
      isPeriodDay: true,
      bleedingIntensity: BleedingIntensity.mittel,
      temperature: 36.7,
      symptoms: const ['Kopfschmerzen'],
      notes: 'Testnotiz',
      cervicalMucus: CervicalMucus.cremig,
      mood: Mood.neutral,
      energyLevel: EnergyLevel.normal,
      sleepHours: 8,
    );

    await database.saveCycleEntry(entry);
    expect(await database.getAllCycleEntries(), [entry]);

    final updatedEntry = CycleEntry(
      id: entry.id,
      date: entry.date,
      isPeriodDay: false,
      symptoms: const ['Übelkeit'],
    );
    await database.updateCycleEntry(updatedEntry);
    expect(await database.getAllCycleEntries(), [updatedEntry]);

    await database.deleteCycleEntry(entry.id);
    expect(await database.getAllCycleEntries(), isEmpty);
  });

  test('upserts by calendar day and ignores the time', () async {
    final original = CycleEntry(
      id: 'original-entry',
      date: DateTime(2026, 11, 24, 8),
      isPeriodDay: true,
      bleedingIntensity: BleedingIntensity.leicht,
      symptoms: const [],
    );
    final legacyDuplicate = CycleEntry(
      id: 'legacy-duplicate',
      date: DateTime(2026, 11, 24, 12),
      isPeriodDay: false,
      bleedingIntensity: BleedingIntensity.stark,
      symptoms: const [],
    );
    final replacement = CycleEntry(
      id: 'replacement-entry',
      date: DateTime(2026, 11, 24, 20, 30),
      isPeriodDay: false,
      bleedingIntensity: BleedingIntensity.mittel,
      temperature: 36.8,
      symptoms: const ['Müdigkeit'],
      cervicalMucus: CervicalMucus.spinnbar,
      mood: Mood.schlecht,
      energyLevel: EnergyLevel.niedrig,
      sleepHours: 6.5,
    );

    await database.saveCycleEntry(original);
    await Hive.box<CycleEntry>(
      'cycle_entries',
    ).put(legacyDuplicate.id, legacyDuplicate);
    await database.saveCycleEntry(replacement);

    final entries = await database.getAllCycleEntries();
    expect(entries, hasLength(1));
    expect(entries.single.id, isIn([original.id, legacyDuplicate.id]));
    expect(entries.single.temperature, replacement.temperature);
    expect(entries.single.cervicalMucus, replacement.cervicalMucus);
    expect(entries.single.mood, replacement.mood);
    expect(entries.single.energyLevel, replacement.energyLevel);
    expect(entries.single.sleepHours, replacement.sleepHours);

    final foundEntry = await database.getEntryByDate(
      DateTime(2026, 11, 24, 23, 59),
    );
    expect(foundEntry?.id, entries.single.id);
    expect(await database.getEntryByDate(DateTime(2026, 11, 25)), isNull);
  });

  test('concurrent saves still keep one entry per calendar day', () async {
    final firstEntry = CycleEntry(
      id: 'concurrent-first',
      date: DateTime(2026, 12, 1, 8),
      isPeriodDay: true,
      bleedingIntensity: BleedingIntensity.leicht,
      symptoms: const [],
    );
    final secondEntry = CycleEntry(
      id: 'concurrent-second',
      date: DateTime(2026, 12, 1, 20),
      isPeriodDay: false,
      bleedingIntensity: BleedingIntensity.mittel,
      symptoms: const [],
    );

    await Future.wait([
      database.saveCycleEntry(firstEntry),
      database.saveCycleEntry(secondEntry),
    ]);

    final entries = await database.getAllCycleEntries();
    expect(
      entries.where(
        (entry) =>
            entry.date.year == 2026 &&
            entry.date.month == 12 &&
            entry.date.day == 1,
      ),
      hasLength(1),
    );
  });
}
