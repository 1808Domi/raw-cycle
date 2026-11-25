import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../cycle_tracking/data/database_service.dart';
import '../../cycle_tracking/data/models/cycle_entry.dart';
import 'settings_service.dart';

class BackupService {
  BackupService._();

  static const _formatVersion = 1;

  static Future<bool> exportBackup({Rect? sharePositionOrigin}) async {
    final entries = await DatabaseService.instance.getAllCycleEntries();
    final settings = await SettingsService.instance.load();
    final now = DateTime.now();
    final backup = {
      'formatVersion': _formatVersion,
      'createdAt': now.toIso8601String(),
      'settings': settings.toJson(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
    };
    final fileName =
        'raw_cycle_backup_${now.year.toString().padLeft(4, '0')}_'
        '${now.month.toString().padLeft(2, '0')}_'
        '${now.day.toString().padLeft(2, '0')}.json';
    final temporaryDirectory = await getTemporaryDirectory();
    final backupFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}$fileName',
    );
    await backupFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backup),
      encoding: utf8,
      flush: true,
    );

    final result = await SharePlus.instance.share(
      ShareParams(
        title: 'Raw Cycle Backup',
        subject: fileName,
        files: [XFile(backupFile.path, mimeType: 'application/json')],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return result.status == ShareResultStatus.success;
  }

  static Future<void> importBackup(List<int> bytes) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['formatVersion'] is! int ||
        decoded['formatVersion'] != _formatVersion ||
        decoded['createdAt'] is! String ||
        DateTime.tryParse(decoded['createdAt'] as String) == null ||
        decoded['settings'] is! Map<String, dynamic> ||
        decoded['entries'] is! List) {
      throw const FormatException('Ungültiges Raw-Cycle-Backup.');
    }

    final settings = CycleSettings.fromJson(
      decoded['settings'] as Map<String, dynamic>,
    );
    _validateSettings(settings);
    final entries = <CycleEntry>[];
    final entryIds = <String>{};
    final entryDates = <String>{};
    for (final item in decoded['entries'] as List) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Ungültiger Zykluseintrag im Backup.');
      }
      final entry = CycleEntry.fromJson(item);
      if (entry.id.trim().isEmpty || !entryIds.add(entry.id)) {
        throw const FormatException(
          'Das Backup enthält eine ungültige oder doppelte Eintrags-ID.',
        );
      }
      final dateKey =
          '${entry.date.year}-${entry.date.month}-${entry.date.day}';
      if (!entryDates.add(dateKey)) {
        throw const FormatException(
          'Das Backup enthält mehrere Einträge für denselben Kalendertag.',
        );
      }
      entries.add(entry);
    }

    final database = DatabaseService.instance;
    final settingsService = SettingsService.instance;
    final previousEntries = await database.getAllCycleEntries();
    final previousSettings = await settingsService.load();

    try {
      await database.replaceAllCycleEntries(entries);
      await settingsService.save(settings);
    } catch (error, stackTrace) {
      try {
        await database.replaceAllCycleEntries(previousEntries);
        await settingsService.save(previousSettings);
      } catch (restoreError) {
        throw StateError(
          'Backup-Import fehlgeschlagen: $error. '
          'Die vorherigen Daten konnten nicht vollständig '
          'wiederhergestellt werden: $restoreError',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static void _validateSettings(CycleSettings settings) {
    if (!_isValidTime(settings.periodReminderTime) ||
        !_isValidTime(settings.ovulationReminderTime) ||
        !_isValidTime(settings.dailyReminderTime) ||
        settings.periodReminderLeadDays < 0 ||
        settings.periodReminderLeadDays > 3 ||
        settings.ovulationReminderLeadDays < 0 ||
        settings.ovulationReminderLeadDays > 3) {
      throw const FormatException('Ungültige Einstellungen im Backup.');
    }
  }

  static bool _isValidTime(String time) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
    if (match == null) {
      return false;
    }
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    return hour < 24 && minute < 60;
  }
}
