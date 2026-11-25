import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../cycle_tracking/data/database_service.dart';
import '../../cycle_tracking/data/models/cycle_entry.dart';
import '../../../services/cycle_service.dart';
import '../../../widgets/cycle_entry_dialog.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    this.initialDate,
    this.entriesFuture,
    this.cycleService,
  });

  final DateTime? initialDate;

  @visibleForTesting
  final Future<List<CycleEntry>>? entriesFuture;

  @visibleForTesting
  final CycleService? cycleService;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const _periodMarkerColor = Color(0xFFD95364);
  static const _predictedPeriodMarkerColor = Color(0xFFEF8C42);
  static const _fertileMarkerColor = Color(0xFF57A773);
  static const _ovulationMarkerColor = Color(0xFF9672C5);
  static const _temperatureMarkerColor = Color(0xFF5486C6);
  static const _normalMarkerColor = Color(0xFF92939A);

  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late Future<_CalendarData> _calendarDataFuture;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate ?? DateTime.now();
    _selectedDay = _focusedDay;
    _loadEntries();
  }

  void _loadEntries() {
    final entriesFuture =
        widget.entriesFuture ?? DatabaseService.instance.getAllCycleEntries();
    final cycleService =
        widget.cycleService ??
        (widget.entriesFuture == null
            ? CycleService.instance
            : CycleService(
                entriesProvider: () => entriesFuture,
                clock: () => widget.initialDate ?? DateTime.now(),
              ));
    _calendarDataFuture = _loadCalendarData(entriesFuture, cycleService);
  }

  Future<_CalendarData> _loadCalendarData(
    Future<List<CycleEntry>> entriesFuture,
    CycleService cycleService,
  ) async {
    final (
      entries,
      predictedPeriodDays,
      predictedFertileDays,
      ovulationDays,
    ) = await (
      entriesFuture,
      cycleService.getPredictedPeriodDays(),
      cycleService.getPredictedFertileDays(),
      cycleService.getPredictedOvulationDay(),
    ).wait;

    return _CalendarData(
      entriesByDay: _indexEntriesByDay(entries),
      predictedPeriodDays: _indexDatesByDay(predictedPeriodDays),
      predictedFertileDays: _indexDatesByDay(predictedFertileDays),
      predictedOvulationDays: _indexDatesByDay(ovulationDays),
    );
  }

  Map<DateTime, CycleEntry> _indexEntriesByDay(List<CycleEntry> entries) {
    return {
      for (final entry in entries)
        DateTime.utc(entry.date.year, entry.date.month, entry.date.day): entry,
    };
  }

  Set<DateTime> _indexDatesByDay(List<DateTime> dates) {
    return {
      for (final date in dates) DateTime.utc(date.year, date.month, date.day),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        FutureBuilder<_CalendarData>(
          future: _calendarDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _CalendarCard(
                child: const SizedBox(
                  height: 360,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return _CalendarCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Zykluseinträge konnten nicht geladen werden: '
                    '${snapshot.error}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              );
            }

            final calendarData = snapshot.data!;
            return _CalendarCard(
              child: TableCalendar<CycleEntry>(
                locale: 'de_DE',
                firstDay: DateTime.utc(1900, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: 'Monat'},
                startingDayOfWeek: StartingDayOfWeek.monday,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) {
                  final entry = calendarData
                      .entriesByDay[DateTime.utc(day.year, day.month, day.day)];
                  return entry == null ? const [] : [entry];
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarBuilders: CalendarBuilders<CycleEntry>(
                  markerBuilder: (context, day, entries) {
                    final dateKey = DateTime.utc(day.year, day.month, day.day);
                    return _buildMarkers(
                      entries,
                      isPredictedPeriod: calendarData.predictedPeriodDays
                          .contains(dateKey),
                      isPredictedFertile: calendarData.predictedFertileDays
                          .contains(dateKey),
                      isPredictedOvulation: calendarData.predictedOvulationDays
                          .contains(dateKey),
                    );
                  },
                ),
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: theme.textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left_rounded,
                    color: colorScheme.primary,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: theme.textTheme.labelMedium!.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  weekendStyle: theme.textTheme.labelMedium!.copyWith(
                    color: _periodMarkerColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  isTodayHighlighted: true,
                  defaultTextStyle: theme.textTheme.bodyMedium!,
                  weekendTextStyle: theme.textTheme.bodyMedium!.copyWith(
                    color: _periodMarkerColor,
                  ),
                  todayDecoration: BoxDecoration(
                    color: _periodMarkerColor.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(color: _periodMarkerColor, width: 1.5),
                  ),
                  todayTextStyle: theme.textTheme.bodyMedium!.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppTheme.lavender,
                    shape: BoxShape.circle,
                    border: Border.all(color: _periodMarkerColor, width: 2),
                  ),
                  selectedTextStyle: theme.textTheme.bodyMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  cellMargin: const EdgeInsets.all(4),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildLegend(context),
        const SizedBox(height: 20),
        FutureBuilder<_CalendarData>(
          future: _calendarDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildEntryDetailsCard(context, isLoading: true);
            }

            if (snapshot.hasError) {
              return _buildEntryDetailsCard(
                context,
                error: 'Eintrag konnte nicht geladen werden: ${snapshot.error}',
              );
            }

            final entriesByDay = snapshot.data!.entriesByDay;
            final selectedEntry =
                entriesByDay[DateTime.utc(
                  _selectedDay.year,
                  _selectedDay.month,
                  _selectedDay.day,
                )];
            return _buildEntryDetailsCard(context, entry: selectedEntry);
          },
        ),
      ],
    );
  }

  Widget _buildEntryDetailsCard(
    BuildContext context, {
    CycleEntry? entry,
    bool isLoading = false,
    String? error,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateText = DateFormat(
      'EEEE, d. MMMM yyyy',
      'de_DE',
    ).format(_selectedDay);

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              dateText,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              )
            else if (entry == null)
              Text(
                'Für diesen Tag existiert noch kein Eintrag.',
                style: theme.textTheme.bodyLarge,
              )
            else ...[
              _DetailRow(
                label: 'Periode',
                value: entry.isPeriodDay ? 'Ja' : 'Nein',
              ),
              _DetailRow(
                label: 'Blutungsstärke',
                value: _intensityLabel(entry.bleedingIntensity),
              ),
              _DetailRow(
                label: 'Temperatur',
                value: entry.temperature == null
                    ? 'Nicht erfasst'
                    : '${entry.temperature} °C',
              ),
              _DetailRow(
                label: 'Symptome',
                value: entry.symptoms.isEmpty
                    ? 'Keine'
                    : entry.symptoms.join(', '),
              ),
              _DetailRow(
                label: 'Notiz',
                value: entry.notes?.trim().isNotEmpty == true
                    ? entry.notes!.trim()
                    : 'Keine',
              ),
            ],
            if (error == null && !isLoading) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openEntryDialog,
                icon: Icon(
                  entry == null ? Icons.add_rounded : Icons.edit_rounded,
                ),
                label: Text(
                  entry == null ? 'Eintrag erstellen' : 'Eintrag bearbeiten',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openEntryDialog() async {
    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) => CycleEntryDialog(initialDate: _selectedDay),
    );

    if (didSave == true && mounted) {
      setState(() {
        _loadEntries();
      });
    }
  }

  static String _intensityLabel(BleedingIntensity? intensity) {
    return switch (intensity) {
      null => 'Nicht erfasst',
      BleedingIntensity.leicht => 'Leicht',
      BleedingIntensity.mittel => 'Mittel',
      BleedingIntensity.stark => 'Stark',
    };
  }

  Widget? _buildMarkers(
    List<CycleEntry> entries, {
    required bool isPredictedPeriod,
    required bool isPredictedFertile,
    required bool isPredictedOvulation,
  }) {
    final entry = entries.isEmpty ? null : entries.first;
    if (entry == null &&
        !isPredictedPeriod &&
        !isPredictedFertile &&
        !isPredictedOvulation) {
      return null;
    }

    final colors = <Color>[
      if (entry?.isPeriodDay == true) _periodMarkerColor,
      if (isPredictedPeriod) _predictedPeriodMarkerColor,
      if (isPredictedFertile) _fertileMarkerColor,
      if (isPredictedOvulation) _ovulationMarkerColor,
      if (entry?.temperature != null) _temperatureMarkerColor,
      if (entry != null && !entry.isPeriodDay && entry.temperature == null)
        _normalMarkerColor,
    ];

    return PositionedDirectional(
      bottom: 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < colors.length; index++)
            Padding(
              padding: EdgeInsetsDirectional.only(start: index == 0 ? 0 : 3),
              child: Container(
                key: ValueKey('calendar-marker-${_markerName(colors[index])}'),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: colors[index],
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _LegendChip(color: _periodMarkerColor, label: 'Periode'),
        _LegendChip(
          color: _predictedPeriodMarkerColor,
          label: 'Erwartete Periode',
        ),
        _LegendChip(color: _fertileMarkerColor, label: 'Fruchtbare Tage'),
        _LegendChip(color: _ovulationMarkerColor, label: 'Eisprung'),
        _LegendChip(color: _temperatureMarkerColor, label: 'Temperaturdaten'),
        _LegendChip(color: _normalMarkerColor, label: 'Eintrag'),
      ],
    );
  }

  String _markerName(Color color) {
    if (color == _periodMarkerColor) return 'red';
    if (color == _predictedPeriodMarkerColor) return 'orange';
    if (color == _fertileMarkerColor) return 'green';
    if (color == _ovulationMarkerColor) return 'purple';
    if (color == _temperatureMarkerColor) return 'blue';
    return 'gray';
  }
}

class _CalendarData {
  const _CalendarData({
    required this.entriesByDay,
    required this.predictedPeriodDays,
    required this.predictedFertileDays,
    required this.predictedOvulationDays,
  });

  final Map<DateTime, CycleEntry> entriesByDay;
  final Set<DateTime> predictedPeriodDays;
  final Set<DateTime> predictedFertileDays;
  final Set<DateTime> predictedOvulationDays;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text(label),
      backgroundColor: colorScheme.surfaceContainerLow,
      side: BorderSide(color: color.withValues(alpha: 0.32)),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
