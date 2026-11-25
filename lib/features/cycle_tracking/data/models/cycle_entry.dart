import 'package:hive_ce/hive.dart';

part 'cycle_entry.g.dart';

@HiveType(typeId: 1)
enum BleedingIntensity {
  @HiveField(0)
  leicht,
  @HiveField(1)
  mittel,
  @HiveField(2)
  stark,
}

@HiveType(typeId: 3)
enum CervicalMucus {
  @HiveField(0)
  trocken,
  @HiveField(1)
  klebrig,
  @HiveField(2)
  cremig,
  @HiveField(3)
  waessrig,
  @HiveField(4)
  spinnbar,
}

@HiveType(typeId: 4)
enum Mood {
  @HiveField(0)
  sehrGut,
  @HiveField(1)
  gut,
  @HiveField(2)
  neutral,
  @HiveField(3)
  schlecht,
  @HiveField(4)
  sehrSchlecht,
}

@HiveType(typeId: 5)
enum EnergyLevel {
  @HiveField(0)
  hoch,
  @HiveField(1)
  normal,
  @HiveField(2)
  niedrig,
}

@HiveType(typeId: 2)
final class CycleEntry {
  const CycleEntry({
    required this.id,
    required this.date,
    required this.isPeriodDay,
    this.bleedingIntensity,
    required this.symptoms,
    this.temperature,
    this.notes,
    this.cervicalMucus,
    this.mood,
    this.energyLevel,
    this.sleepHours,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final bool isPeriodDay;

  @HiveField(3)
  final BleedingIntensity? bleedingIntensity;

  @HiveField(4)
  final double? temperature;

  @HiveField(5)
  final List<String> symptoms;

  @HiveField(6)
  final String? notes;

  @HiveField(7)
  final CervicalMucus? cervicalMucus;

  @HiveField(8)
  final Mood? mood;

  @HiveField(9)
  final EnergyLevel? energyLevel;

  @HiveField(10)
  final double? sleepHours;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'isPeriodDay': isPeriodDay,
      'bleedingIntensity': bleedingIntensity?.name,
      'temperature': temperature,
      'symptoms': symptoms.toList(),
      'notes': notes,
      'cervicalMucus': cervicalMucus?.name,
      'mood': mood?.name,
      'energyLevel': energyLevel?.name,
      'sleepHours': sleepHours,
    };
  }

  factory CycleEntry.fromJson(Map<String, dynamic> json) {
    return CycleEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      isPeriodDay: json['isPeriodDay'] as bool,
      bleedingIntensity: json['bleedingIntensity'] == null
          ? null
          : BleedingIntensity.values.byName(
              json['bleedingIntensity'] as String,
            ),
      temperature: (json['temperature'] as num?)?.toDouble(),
      symptoms: List<String>.from(json['symptoms'] as List<dynamic>),
      notes: json['notes'] as String?,
      cervicalMucus: json['cervicalMucus'] == null
          ? null
          : CervicalMucus.values.byName(json['cervicalMucus'] as String),
      mood: json['mood'] == null
          ? null
          : Mood.values.byName(json['mood'] as String),
      energyLevel: json['energyLevel'] == null
          ? null
          : EnergyLevel.values.byName(json['energyLevel'] as String),
      sleepHours: (json['sleepHours'] as num?)?.toDouble(),
    );
  }
}
