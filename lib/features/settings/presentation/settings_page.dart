import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../../../services/notification_service.dart';
import '../../app_protection/data/pin_credential_service.dart';
import '../data/backup_service.dart';
import '../data/settings_service.dart';

typedef ReminderSettingsSynchronizer =
    Future<void> Function(
      CycleSettings settings, {
      required bool syncDaily,
      required bool syncPeriod,
      required bool syncOvulation,
    });

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    @visibleForTesting this.reminderSettingsSynchronizer,
    @visibleForTesting this.settingsSaver,
    @visibleForTesting this.pinCredentialRepository,
  });

  @visibleForTesting
  final ReminderSettingsSynchronizer? reminderSettingsSynchronizer;

  @visibleForTesting
  final Future<void> Function(CycleSettings settings)? settingsSaver;

  @visibleForTesting
  final PinCredentialRepository? pinCredentialRepository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<CycleSettings> _settingsFuture;
  CycleSettings? _settings;
  bool _backupInProgress = false;
  int _saveRequest = 0;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _loadSettings();
  }

  Future<CycleSettings> _loadSettings() async {
    final service = SettingsService.instance;
    if (!service.isInitialized) {
      await service.init();
    }
    final settings = await service.load();
    _settings = settings;
    return settings;
  }

  Future<void> _updateSettings(CycleSettings settings) async {
    final previousSettings = _settings;
    final request = ++_saveRequest;
    final syncDaily =
        previousSettings == null ||
        previousSettings.dailyReminderEnabled !=
            settings.dailyReminderEnabled ||
        previousSettings.dailyReminderTime != settings.dailyReminderTime;
    final syncPeriod =
        previousSettings == null ||
        previousSettings.periodReminderEnabled !=
            settings.periodReminderEnabled ||
        previousSettings.periodReminderTime != settings.periodReminderTime ||
        previousSettings.periodReminderLeadDays !=
            settings.periodReminderLeadDays;
    final syncOvulation =
        previousSettings == null ||
        previousSettings.ovulationReminderEnabled !=
            settings.ovulationReminderEnabled ||
        previousSettings.ovulationReminderTime !=
            settings.ovulationReminderTime ||
        previousSettings.ovulationReminderLeadDays !=
            settings.ovulationReminderLeadDays;
    setState(() {
      _settings = settings;
    });

    try {
      final saveSettings =
          widget.settingsSaver ?? SettingsService.instance.save;
      await saveSettings(settings);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (request == _saveRequest) {
        setState(() {
          _settings = previousSettings;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Einstellung konnte nicht gespeichert werden: $error'),
        ),
      );
      return;
    }

    if (!syncDaily && !syncPeriod && !syncOvulation) {
      return;
    }

    try {
      final synchronize =
          widget.reminderSettingsSynchronizer ??
          NotificationService.instance.syncWithSettings;
      await synchronize(
        settings,
        syncDaily: syncDaily,
        syncPeriod: syncPeriod,
        syncOvulation: syncOvulation,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Einstellung wurde gespeichert, aber die Erinnerung konnte '
            'nicht geplant werden: $error',
          ),
        ),
      );
    }
  }

  Future<void> _selectReminderTime({
    required String currentTime,
    required Future<void> Function(String) onSelected,
  }) async {
    final parts = currentTime.split(':');
    final selectedTime = await showTimePicker(
      context: context,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (selectedTime == null) {
      return;
    }
    await onSelected(
      '${selectedTime.hour.toString().padLeft(2, '0')}:'
      '${selectedTime.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _setAppProtectionEnabled(
    CycleSettings settings,
    bool enabled,
  ) async {
    if (enabled &&
        settings.appProtectionMethod == AppProtectionMethod.pin &&
        !await _ensurePinConfigured()) {
      return;
    }
    await _updateSettings(settings.copyWith(appProtectionEnabled: enabled));
  }

  Future<void> _setAppProtectionMethod(
    CycleSettings settings,
    AppProtectionMethod? method,
  ) async {
    if (method == null) {
      return;
    }
    if (method == AppProtectionMethod.pin && !await _ensurePinConfigured()) {
      return;
    }
    await _updateSettings(settings.copyWith(appProtectionMethod: method));
  }

  Future<bool> _ensurePinConfigured() async {
    final credentials =
        widget.pinCredentialRepository ?? PinCredentialService.instance;
    try {
      if (await credentials.isPinConfigured()) {
        return true;
      }
      if (!mounted) {
        return false;
      }
      final pin = await showDialog<String>(
        context: context,
        builder: (context) => const _PinSetupDialog(),
      );
      if (pin == null) {
        return false;
      }
      await credentials.setPin(pin);
      return true;
    } catch (error) {
      if (mounted) {
        _showMessage('PIN konnte nicht eingerichtet werden: $error');
      }
      return false;
    }
  }

  Future<void> _exportBackup() async {
    await _runBackupAction(() async {
      final screenSize = MediaQuery.sizeOf(context);
      final exported = await BackupService.exportBackup(
        sharePositionOrigin: Rect.fromLTWH(
          0,
          0,
          screenSize.width,
          screenSize.height,
        ),
      );
      if (exported && mounted) {
        _showMessage('Backup wurde exportiert.');
      }
    });
  }

  Future<void> _importBackup() async {
    await _runBackupAction(() async {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Raw Cycle Backup auswählen',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (files.isEmpty || !mounted) {
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup importieren?'),
          content: const Text(
            'Dabei werden die vorhandenen Zykluseinträge und Einstellungen '
            'durch die Daten aus dem Backup ersetzt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importieren'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }

      final bytes = await files.single.readAsBytes();
      await BackupService.importBackup(bytes);
      if (!mounted) {
        return;
      }
      final importedSettings = await SettingsService.instance.load();
      setState(() {
        _settings = importedSettings;
        _settingsFuture = Future.value(importedSettings);
      });
      try {
        await NotificationService.instance.syncWithSettings(importedSettings);
      } catch (error) {
        if (mounted) {
          _showMessage(
            'Backup importiert, aber Erinnerungen konnten nicht geplant '
            'werden: $error',
          );
        }
        return;
      }
      _showMessage('Backup wurde importiert.');
    });
  }

  Future<void> _runBackupAction(Future<void> Function() action) async {
    setState(() {
      _backupInProgress = true;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _showMessage('Backup konnte nicht verarbeitet werden: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _backupInProgress = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CycleSettings>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError && _settings == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Einstellungen konnten nicht geladen werden: '
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => setState(() {
                      _settingsFuture = _loadSettings();
                    }),
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            ),
          );
        }

        final settings = _settings ?? snapshot.data;
        if (settings == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Deine Einstellungen',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Passe Raw Cycle an deine Bedürfnisse an.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _SettingsCard(
              icon: Icons.water_drop_outlined,
              title: 'Periodenerinnerung',
              subtitle: 'Erinnert dich vor dem erwarteten Periodenbeginn',
              child: _ReminderControls(
                enabled: settings.periodReminderEnabled,
                onEnabledChanged: (value) => _updateSettings(
                  settings.copyWith(periodReminderEnabled: value),
                ),
                time: settings.periodReminderTime,
                onSelectTime: () => _selectReminderTime(
                  currentTime: settings.periodReminderTime,
                  onSelected: (time) => _updateSettings(
                    settings.copyWith(periodReminderTime: time),
                  ),
                ),
                leadDays: settings.periodReminderLeadDays,
                onLeadDaysChanged: (value) => _updateSettings(
                  settings.copyWith(periodReminderLeadDays: value),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              icon: Icons.egg_alt_outlined,
              title: 'Eisprungerinnerung',
              subtitle: 'Erinnert dich vor dem geschätzten Eisprung',
              child: _ReminderControls(
                enabled: settings.ovulationReminderEnabled,
                onEnabledChanged: (value) => _updateSettings(
                  settings.copyWith(ovulationReminderEnabled: value),
                ),
                time: settings.ovulationReminderTime,
                onSelectTime: () => _selectReminderTime(
                  currentTime: settings.ovulationReminderTime,
                  onSelected: (time) => _updateSettings(
                    settings.copyWith(ovulationReminderTime: time),
                  ),
                ),
                leadDays: settings.ovulationReminderLeadDays,
                onLeadDaysChanged: (value) => _updateSettings(
                  settings.copyWith(ovulationReminderLeadDays: value),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              icon: Icons.today_outlined,
              title: 'Tägliche Erinnerung',
              subtitle: 'Eine tägliche Erinnerung zu deiner Wunschzeit',
              child: _ReminderControls(
                enabled: settings.dailyReminderEnabled,
                onEnabledChanged: (value) => _updateSettings(
                  settings.copyWith(dailyReminderEnabled: value),
                ),
                time: settings.dailyReminderTime,
                onSelectTime: () => _selectReminderTime(
                  currentTime: settings.dailyReminderTime,
                  onSelected: (time) => _updateSettings(
                    settings.copyWith(dailyReminderTime: time),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              icon: Icons.thermostat_rounded,
              title: 'Temperaturmessung',
              subtitle: 'Wähle deine bevorzugte Messmethode',
              child: DropdownButtonFormField<TemperatureMeasurement>(
                initialValue: settings.temperatureMeasurement,
                decoration: const InputDecoration(
                  labelText: 'Messmethode',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                items: TemperatureMeasurement.values
                    .map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(_measurementLabel(method)),
                      ),
                    )
                    .toList(),
                onChanged: (method) {
                  if (method != null) {
                    _updateSettings(
                      settings.copyWith(temperatureMeasurement: method),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              icon: Icons.shield_outlined,
              title: 'Datenschutz',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Alle Daten werden ausschließlich lokal auf diesem Gerät gespeichert.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              icon: Icons.lock_outline_rounded,
              title: 'App-Schutz',
              subtitle: 'Lege fest, wie Raw Cycle geschützt werden soll',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('App-Schutz aktivieren'),
                    value: settings.appProtectionEnabled,
                    onChanged: (value) =>
                        _setAppProtectionEnabled(settings, value),
                  ),
                  if (settings.appProtectionEnabled) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AppProtectionMethod>(
                      initialValue: settings.appProtectionMethod,
                      decoration: const InputDecoration(
                        labelText: 'Authentifizierungsmethode',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                      items: AppProtectionMethod.values
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(_appProtectionMethodLabel(method)),
                            ),
                          )
                          .toList(),
                      onChanged: (method) =>
                          _setAppProtectionMethod(settings, method),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AppProtectionCheckMode>(
                      initialValue: settings.appProtectionCheckMode,
                      decoration: const InputDecoration(
                        labelText: 'Prüfzeitpunkt',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                      items: AppProtectionCheckMode.values
                          .map(
                            (mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(_appProtectionCheckModeLabel(mode)),
                            ),
                          )
                          .toList(),
                      onChanged: (mode) {
                        if (mode != null) {
                          _updateSettings(
                            settings.copyWith(appProtectionCheckMode: mode),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              icon: Icons.backup_outlined,
              title: 'Backup',
              subtitle: 'Sichere deine Daten oder stelle sie wieder her',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _backupInProgress ? null : _exportBackup,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Backup exportieren'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _backupInProgress ? null : _importBackup,
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Backup importieren'),
                  ),
                  if (_backupInProgress) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatTime(BuildContext context, String value) {
    final parts = value.split(':');
    final time = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time, alwaysUse24HourFormat: true);
  }

  static String _measurementLabel(TemperatureMeasurement method) {
    return switch (method) {
      TemperatureMeasurement.oral => 'Oral',
      TemperatureMeasurement.vaginal => 'Vaginal',
      TemperatureMeasurement.rectal => 'Rektal',
      TemperatureMeasurement.axillary => 'Axillar',
    };
  }

  static String _appProtectionMethodLabel(AppProtectionMethod method) {
    return switch (method) {
      AppProtectionMethod.deviceUnlock => 'Geräteentsperrung',
      AppProtectionMethod.pin => 'PIN',
      AppProtectionMethod.biometrics => 'Biometrie',
    };
  }

  static String _appProtectionCheckModeLabel(AppProtectionCheckMode mode) {
    return switch (mode) {
      AppProtectionCheckMode.appStartOnly => 'Nur beim App-Start prüfen',
      AppProtectionCheckMode.afterInactivity =>
        'Nach Inaktivität erneut prüfen',
    };
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _savePin() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_pinController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('PIN einrichten'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Deine PIN wird geschützt auf diesem Gerät gespeichert.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _pinController,
                autofocus: true,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 12,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Neue PIN',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                validator: (value) =>
                    PinCredentialService.isValidPin(value ?? '')
                    ? null
                    : 'Verwende 4 bis 12 Ziffern.',
                onFieldSubmitted: (_) => _savePin(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmationController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 12,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'PIN bestätigen',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                validator: (value) {
                  if (value != _pinController.text) {
                    return 'Die PINs stimmen nicht überein.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _savePin(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _savePin, child: const Text('PIN speichern')),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(icon, color: colors.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReminderControls extends StatelessWidget {
  const _ReminderControls({
    required this.enabled,
    required this.onEnabledChanged,
    required this.time,
    required this.onSelectTime,
    this.leadDays,
    this.onLeadDaysChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final String time;
  final VoidCallback onSelectTime;
  final int? leadDays;
  final ValueChanged<int>? onLeadDaysChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Erinnerung aktivieren'),
          value: enabled,
          onChanged: onEnabledChanged,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onSelectTime,
          icon: const Icon(Icons.schedule_rounded),
          label: Text(
            'Uhrzeit auswählen · '
            '${_SettingsPageState._formatTime(context, time)}',
          ),
        ),
        if (leadDays != null && onLeadDaysChanged != null) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: leadDays,
            decoration: const InputDecoration(
              labelText: 'Vorlaufzeit',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            items: List.generate(
              4,
              (days) => DropdownMenuItem(
                value: days,
                child: Text('$days ${days == 1 ? 'Tag' : 'Tage'} vorher'),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                onLeadDaysChanged!(value);
              }
            },
          ),
        ],
      ],
    );
  }
}
