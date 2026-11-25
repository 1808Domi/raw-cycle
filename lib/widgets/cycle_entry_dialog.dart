import 'package:flutter/material.dart';

import '../features/cycle_tracking/data/database_service.dart';
import '../features/cycle_tracking/data/models/cycle_entry.dart';

class CycleEntryDialog extends StatefulWidget {
  const CycleEntryDialog({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<CycleEntryDialog> createState() => _CycleEntryDialogState();
}

class _CycleEntryDialogState extends State<CycleEntryDialog> {
  static const _symptomOptions = [
    'Kopfschmerzen',
    'Unterleibsschmerzen',
    'Rückenschmerzen',
    'Brustspannen',
    'Müdigkeit',
    'Übelkeit',
  ];

  final _formKey = GlobalKey<FormState>();
  final _temperatureController = TextEditingController();
  final _sleepHoursController = TextEditingController();
  final _notesController = TextEditingController();
  final _selectedSymptoms = <String>{};

  DateTime _date = DateTime.now();
  bool _isPeriodDay = false;
  bool _isLoadingEntry = true;
  bool _isSaving = false;
  BleedingIntensity? _bleedingIntensity;
  CervicalMucus? _cervicalMucus;
  Mood? _mood;
  EnergyLevel? _energyLevel;
  CycleEntry? _existingEntry;
  String? _loadError;
  int _dateLookupRequest = 0;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    _loadEntryForDate(_date);
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _sleepHoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      setState(() {
        _date = selectedDate;
      });
      await _loadEntryForDate(selectedDate);
    }
  }

  Future<void> _loadEntryForDate(DateTime date) async {
    final request = ++_dateLookupRequest;

    setState(() {
      _isLoadingEntry = true;
      _loadError = null;
      _existingEntry = null;
      _resetFormFields();
    });

    try {
      final entry = await DatabaseService.instance.getEntryByDate(date);
      if (!mounted || request != _dateLookupRequest) {
        return;
      }

      setState(() {
        _existingEntry = entry;
        _isLoadingEntry = false;
        if (entry != null) {
          _populateFormFields(entry);
        }
      });
    } catch (error) {
      if (!mounted || request != _dateLookupRequest) {
        return;
      }

      setState(() {
        _isLoadingEntry = false;
        _loadError = 'Eintrag konnte nicht geladen werden: $error';
      });
    }
  }

  void _resetFormFields() {
    _temperatureController.clear();
    _sleepHoursController.clear();
    _notesController.clear();
    _isPeriodDay = false;
    _bleedingIntensity = null;
    _cervicalMucus = null;
    _mood = null;
    _energyLevel = null;
    _selectedSymptoms.clear();
  }

  void _populateFormFields(CycleEntry entry) {
    _temperatureController.text = entry.temperature?.toString() ?? '';
    _sleepHoursController.text = entry.sleepHours?.toString() ?? '';
    _notesController.text = entry.notes ?? '';
    _isPeriodDay = entry.isPeriodDay;
    _bleedingIntensity = entry.isPeriodDay
        ? entry.bleedingIntensity ?? BleedingIntensity.mittel
        : null;
    _cervicalMucus = entry.cervicalMucus;
    _mood = entry.mood;
    _energyLevel = entry.energyLevel;
    _selectedSymptoms
      ..clear()
      ..addAll(entry.symptoms);
  }

  Future<void> _saveEntry() async {
    if (_isLoadingEntry ||
        _loadError != null ||
        !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final temperatureText = _temperatureController.text.trim();
    final sleepHoursText = _sleepHoursController.text.trim();
    final notes = _notesController.text.trim();
    final entry = CycleEntry(
      id:
          _existingEntry?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      date: _date,
      isPeriodDay: _isPeriodDay,
      bleedingIntensity: _isPeriodDay ? _bleedingIntensity : null,
      temperature: temperatureText.isEmpty
          ? null
          : double.parse(temperatureText.replaceAll(',', '.')),
      symptoms: _selectedSymptoms.toList(),
      notes: notes.isEmpty ? null : notes,
      cervicalMucus: _cervicalMucus,
      mood: _mood,
      energyLevel: _energyLevel,
      sleepHours: sleepHoursText.isEmpty
          ? null
          : double.parse(sleepHoursText.replaceAll(',', '.')),
    );

    try {
      if (_existingEntry == null) {
        await DatabaseService.instance.saveCycleEntry(entry);
      } else {
        await DatabaseService.instance.updateCycleEntry(entry);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eintrag konnte nicht gespeichert werden: $error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Neuer Zykluseintrag',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isLoadingEntry)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: LinearProgressIndicator(),
                            ),
                          if (_loadError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _loadError!,
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ),
                          _buildDatePicker(context),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: const Text('Periode'),
                            value: _isPeriodDay,
                            onChanged: (value) {
                              setState(() {
                                _isPeriodDay = value;
                                _bleedingIntensity = value
                                    ? _bleedingIntensity ??
                                          BleedingIntensity.mittel
                                    : null;
                              });
                            },
                          ),
                          if (_isPeriodDay) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<BleedingIntensity>(
                              initialValue: _bleedingIntensity,
                              decoration: const InputDecoration(
                                labelText: 'Blutungsstärke',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                ),
                              ),
                              items: BleedingIntensity.values
                                  .map(
                                    (intensity) =>
                                        DropdownMenuItem<BleedingIntensity>(
                                          value: intensity,
                                          child: Text(
                                            _intensityLabel(intensity),
                                          ),
                                        ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _bleedingIntensity = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _temperatureController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Aufstehtemperatur (optional)',
                              suffixText: '°C',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(16),
                                ),
                              ),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return null;
                              }
                              final temperature = double.tryParse(
                                text.replaceAll(',', '.'),
                              );
                              if (temperature == null ||
                                  !temperature.isFinite) {
                                return 'Bitte eine gültige Temperatur eingeben';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Symptome',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _symptomOptions.map((symptom) {
                              final isSelected = _selectedSymptoms.contains(
                                symptom,
                              );
                              return FilterChip(
                                label: Text(symptom),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedSymptoms.add(symptom);
                                    } else {
                                      _selectedSymptoms.remove(symptom);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<CervicalMucus?>(
                            initialValue: _cervicalMucus,
                            decoration: const InputDecoration(
                              labelText: 'Zervixschleim (optional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(16),
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<CervicalMucus?>(
                                value: null,
                                child: Text('Keine Angabe'),
                              ),
                              ...CervicalMucus.values.map(
                                (value) => DropdownMenuItem<CervicalMucus?>(
                                  value: value,
                                  child: Text(_cervicalMucusLabel(value)),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _cervicalMucus = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<Mood?>(
                            initialValue: _mood,
                            decoration: const InputDecoration(
                              labelText: 'Stimmung (optional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(16),
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<Mood?>(
                                value: null,
                                child: Text('Keine Angabe'),
                              ),
                              ...Mood.values.map(
                                (value) => DropdownMenuItem<Mood?>(
                                  value: value,
                                  child: Text(_moodLabel(value)),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _mood = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<EnergyLevel?>(
                            initialValue: _energyLevel,
                            decoration: const InputDecoration(
                              labelText: 'Energielevel (optional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(16),
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<EnergyLevel?>(
                                value: null,
                                child: Text('Keine Angabe'),
                              ),
                              ...EnergyLevel.values.map(
                                (value) => DropdownMenuItem<EnergyLevel?>(
                                  value: value,
                                  child: Text(_energyLevelLabel(value)),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _energyLevel = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _sleepHoursController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Schlafdauer (optional)',
                              suffixText: 'Std.',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(16),
                                ),
                              ),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return null;
                              }
                              final sleepHours = double.tryParse(
                                text.replaceAll(',', '.'),
                              );
                              if (sleepHours == null ||
                                  !sleepHours.isFinite ||
                                  sleepHours < 0) {
                                return 'Bitte eine gültige Schlafdauer eingeben';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _notesController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Notizen',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Abbrechen'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed:
                          _isSaving || _isLoadingEntry || _loadError != null
                          ? null
                          : _saveEntry,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Speichern'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    final theme = Theme.of(context);
    final dateText = MaterialLocalizations.of(context).formatMediumDate(_date);

    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Datum',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: Text(dateText)),
            Icon(
              Icons.calendar_today_rounded,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  static String _intensityLabel(BleedingIntensity intensity) {
    return switch (intensity) {
      BleedingIntensity.leicht => 'Leicht',
      BleedingIntensity.mittel => 'Mittel',
      BleedingIntensity.stark => 'Stark',
    };
  }

  static String _cervicalMucusLabel(CervicalMucus mucus) {
    return switch (mucus) {
      CervicalMucus.trocken => 'Trocken',
      CervicalMucus.klebrig => 'Klebrig',
      CervicalMucus.cremig => 'Cremig',
      CervicalMucus.waessrig => 'Wässrig',
      CervicalMucus.spinnbar => 'Spinnbar',
    };
  }

  static String _moodLabel(Mood mood) {
    return switch (mood) {
      Mood.sehrGut => 'Sehr gut',
      Mood.gut => 'Gut',
      Mood.neutral => 'Neutral',
      Mood.schlecht => 'Schlecht',
      Mood.sehrSchlecht => 'Sehr schlecht',
    };
  }

  static String _energyLevelLabel(EnergyLevel energyLevel) {
    return switch (energyLevel) {
      EnergyLevel.hoch => 'Hoch',
      EnergyLevel.normal => 'Normal',
      EnergyLevel.niedrig => 'Niedrig',
    };
  }
}
