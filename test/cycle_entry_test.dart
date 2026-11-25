import 'package:flutter_test/flutter_test.dart';
import 'package:raw_cycle/features/cycle_tracking/data/models/cycle_entry.dart';

void main() {
  group('CycleEntry JSON serialization', () {
    test('round trips populated fields', () {
      final entry = CycleEntry(
        id: 'entry-1',
        date: DateTime.utc(2026, 11, 24),
        isPeriodDay: true,
        bleedingIntensity: BleedingIntensity.mittel,
        temperature: 36.7,
        symptoms: const ['Krämpfe', 'Müdigkeit'],
        notes: 'Leichter als gestern',
        cervicalMucus: CervicalMucus.waessrig,
        mood: Mood.sehrGut,
        energyLevel: EnergyLevel.hoch,
        sleepHours: 7.5,
      );

      final restored = CycleEntry.fromJson(entry.toJson());

      expect(restored.id, entry.id);
      expect(restored.date, entry.date);
      expect(restored.isPeriodDay, entry.isPeriodDay);
      expect(restored.bleedingIntensity, entry.bleedingIntensity);
      expect(restored.temperature, entry.temperature);
      expect(restored.symptoms, entry.symptoms);
      expect(restored.notes, entry.notes);
      expect(restored.cervicalMucus, entry.cervicalMucus);
      expect(restored.mood, entry.mood);
      expect(restored.energyLevel, entry.energyLevel);
      expect(restored.sleepHours, entry.sleepHours);
    });

    test('reads optional values as null', () {
      final entry = CycleEntry.fromJson({
        'id': 'entry-2',
        'date': '2026-11-24T00:00:00.000Z',
        'isPeriodDay': false,
        'bleedingIntensity': null,
        'temperature': null,
        'symptoms': <String>[],
        'notes': null,
      });

      expect(entry.temperature, isNull);
      expect(entry.bleedingIntensity, isNull);
      expect(entry.notes, isNull);
      expect(entry.symptoms, isEmpty);
      expect(entry.cervicalMucus, isNull);
      expect(entry.mood, isNull);
      expect(entry.energyLevel, isNull);
      expect(entry.sleepHours, isNull);
    });
  });
}
