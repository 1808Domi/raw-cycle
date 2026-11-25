// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cycle_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CycleEntryAdapter extends TypeAdapter<CycleEntry> {
  @override
  final typeId = 2;

  @override
  CycleEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CycleEntry(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      isPeriodDay: fields[2] as bool,
      bleedingIntensity: fields[3] as BleedingIntensity?,
      symptoms: (fields[5] as List).cast<String>(),
      temperature: (fields[4] as num?)?.toDouble(),
      notes: fields[6] as String?,
      cervicalMucus: fields[7] as CervicalMucus?,
      mood: fields[8] as Mood?,
      energyLevel: fields[9] as EnergyLevel?,
      sleepHours: (fields[10] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, CycleEntry obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.isPeriodDay)
      ..writeByte(3)
      ..write(obj.bleedingIntensity)
      ..writeByte(4)
      ..write(obj.temperature)
      ..writeByte(5)
      ..write(obj.symptoms)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.cervicalMucus)
      ..writeByte(8)
      ..write(obj.mood)
      ..writeByte(9)
      ..write(obj.energyLevel)
      ..writeByte(10)
      ..write(obj.sleepHours);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CycleEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BleedingIntensityAdapter extends TypeAdapter<BleedingIntensity> {
  @override
  final typeId = 1;

  @override
  BleedingIntensity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BleedingIntensity.leicht;
      case 1:
        return BleedingIntensity.mittel;
      case 2:
        return BleedingIntensity.stark;
      default:
        return BleedingIntensity.leicht;
    }
  }

  @override
  void write(BinaryWriter writer, BleedingIntensity obj) {
    switch (obj) {
      case BleedingIntensity.leicht:
        writer.writeByte(0);
      case BleedingIntensity.mittel:
        writer.writeByte(1);
      case BleedingIntensity.stark:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleedingIntensityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CervicalMucusAdapter extends TypeAdapter<CervicalMucus> {
  @override
  final typeId = 3;

  @override
  CervicalMucus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CervicalMucus.trocken;
      case 1:
        return CervicalMucus.klebrig;
      case 2:
        return CervicalMucus.cremig;
      case 3:
        return CervicalMucus.waessrig;
      case 4:
        return CervicalMucus.spinnbar;
      default:
        return CervicalMucus.trocken;
    }
  }

  @override
  void write(BinaryWriter writer, CervicalMucus obj) {
    switch (obj) {
      case CervicalMucus.trocken:
        writer.writeByte(0);
      case CervicalMucus.klebrig:
        writer.writeByte(1);
      case CervicalMucus.cremig:
        writer.writeByte(2);
      case CervicalMucus.waessrig:
        writer.writeByte(3);
      case CervicalMucus.spinnbar:
        writer.writeByte(4);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CervicalMucusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MoodAdapter extends TypeAdapter<Mood> {
  @override
  final typeId = 4;

  @override
  Mood read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Mood.sehrGut;
      case 1:
        return Mood.gut;
      case 2:
        return Mood.neutral;
      case 3:
        return Mood.schlecht;
      case 4:
        return Mood.sehrSchlecht;
      default:
        return Mood.sehrGut;
    }
  }

  @override
  void write(BinaryWriter writer, Mood obj) {
    switch (obj) {
      case Mood.sehrGut:
        writer.writeByte(0);
      case Mood.gut:
        writer.writeByte(1);
      case Mood.neutral:
        writer.writeByte(2);
      case Mood.schlecht:
        writer.writeByte(3);
      case Mood.sehrSchlecht:
        writer.writeByte(4);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EnergyLevelAdapter extends TypeAdapter<EnergyLevel> {
  @override
  final typeId = 5;

  @override
  EnergyLevel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return EnergyLevel.hoch;
      case 1:
        return EnergyLevel.normal;
      case 2:
        return EnergyLevel.niedrig;
      default:
        return EnergyLevel.hoch;
    }
  }

  @override
  void write(BinaryWriter writer, EnergyLevel obj) {
    switch (obj) {
      case EnergyLevel.hoch:
        writer.writeByte(0);
      case EnergyLevel.normal:
        writer.writeByte(1);
      case EnergyLevel.niedrig:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnergyLevelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
