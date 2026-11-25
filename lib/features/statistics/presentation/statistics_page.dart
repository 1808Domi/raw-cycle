import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../cycle_tracking/data/models/cycle_entry.dart';
import '../../../services/cycle_service.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, this.cycleService});

  @visibleForTesting
  final CycleService? cycleService;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late CycleService _cycleService;
  late Future<CycleStatistics> _statisticsFuture;
  StreamSubscription<void>? _changesSubscription;

  @override
  void initState() {
    super.initState();
    _configureCycleService();
  }

  @override
  void didUpdateWidget(covariant StatisticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cycleService != widget.cycleService) {
      _configureCycleService();
    }
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    super.dispose();
  }

  void _configureCycleService() {
    _changesSubscription?.cancel();
    _cycleService = widget.cycleService ?? CycleService.instance;
    _statisticsFuture = _cycleService.getStatistics();
    _changesSubscription = _cycleService.entryChanges?.listen(
      (_) {
        if (mounted) {
          setState(() {
            _statisticsFuture = _cycleService.getStatistics();
          });
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (mounted) {
          setState(() {
            _statisticsFuture = Future<CycleStatistics>.error(
              error,
              stackTrace,
            );
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<CycleStatistics>(
      future: _statisticsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Statistiken konnten nicht geladen werden: '
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => setState(() {
                      _statisticsFuture = _cycleService.getStatistics();
                    }),
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            ),
          );
        }

        final statistics = snapshot.data;
        if (statistics == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final hasEntries = statistics.entryCount > 0;
        final colors = theme.colorScheme;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Dein Zyklus im Überblick',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Persönliche Einblicke aus deinen gespeicherten Einträgen.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (!hasEntries) ...[
              const SizedBox(height: 16),
              _EmptyOverviewCard(),
            ],
            const SizedBox(height: 20),
            _StatisticsCard(
              icon: Icons.autorenew_rounded,
              title: 'Zyklusanalyse',
              subtitle: 'Berechnet aus den Abständen zwischen Periodenstarts',
              child: _MetricRow(
                metrics: [
                  _Metric(
                    label: 'Durchschnitt',
                    value: _daysValue(statistics.averageCycleLength),
                  ),
                  _Metric(
                    label: 'Kürzester',
                    value: _daysValue(statistics.shortestCycleLength),
                  ),
                  _Metric(
                    label: 'Längster',
                    value: _daysValue(statistics.longestCycleLength),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _StatisticsCard(
              icon: Icons.water_drop_outlined,
              title: 'Periodenanalyse',
              subtitle: 'Nur abgeschlossene Perioden werden berücksichtigt',
              child: _MetricRow(
                metrics: [
                  _Metric(
                    label: 'Durchschnitt',
                    value: _daysValue(statistics.averagePeriodLength),
                  ),
                  _Metric(
                    label: 'Kürzeste',
                    value: _daysValue(statistics.shortestPeriodLength),
                  ),
                  _Metric(
                    label: 'Längste',
                    value: _daysValue(statistics.longestPeriodLength),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _StatisticsCard(
              icon: Icons.healing_outlined,
              title: 'Häufigste Symptome',
              subtitle: 'Die fünf am häufigsten erfassten Symptome',
              child: statistics.frequentSymptoms.isEmpty
                  ? const _InlineEmptyState(
                      text: 'Es wurden noch keine Symptome erfasst.',
                    )
                  : _FrequencyList(
                      items: [
                        for (final symptom in statistics.frequentSymptoms)
                          _FrequencyItem(
                            label: symptom.name,
                            count: symptom.count,
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _StatisticsCard(
              icon: Icons.mood_rounded,
              title: 'Stimmungsauswertung',
              subtitle: 'Anzahl der Einträge je Stimmung',
              child: _EnumFrequencyList<Mood>(
                counts: statistics.moodCounts,
                labels: const {
                  Mood.sehrGut: 'Sehr gut',
                  Mood.gut: 'Gut',
                  Mood.neutral: 'Neutral',
                  Mood.schlecht: 'Schlecht',
                  Mood.sehrSchlecht: 'Sehr schlecht',
                },
                emptyText: 'Es wurden noch keine Stimmungen erfasst.',
              ),
            ),
            const SizedBox(height: 16),
            _StatisticsCard(
              icon: Icons.bolt_rounded,
              title: 'Energielevel-Auswertung',
              subtitle: 'Anzahl der Einträge je Energielevel',
              child: _EnumFrequencyList<EnergyLevel>(
                counts: statistics.energyLevelCounts,
                labels: const {
                  EnergyLevel.hoch: 'Hoch',
                  EnergyLevel.normal: 'Normal',
                  EnergyLevel.niedrig: 'Niedrig',
                },
                emptyText: 'Es wurden noch keine Energielevel erfasst.',
              ),
            ),
            const SizedBox(height: 16),
            _StatisticsCard(
              icon: Icons.insights_rounded,
              title: 'Datenbasis',
              subtitle: 'Grundlage deiner persönlichen Auswertung',
              child: _MetricRow(
                metrics: [
                  _Metric(label: 'Einträge', value: '${statistics.entryCount}'),
                  _Metric(
                    label: 'Zyklen',
                    value: '${statistics.recognizedCycleCount}',
                  ),
                  _Metric(
                    label: 'Erster Eintrag',
                    value: statistics.firstEntryDate == null
                        ? '–'
                        : DateFormat(
                            'd. MMM yyyy',
                            'de_DE',
                          ).format(statistics.firstEntryDate!),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _daysValue(int? days) => days == null ? '–' : '$days Tage';
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
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
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: _MetricTile(metric: metrics[index])),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          metric.label,
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FrequencyItem {
  const _FrequencyItem({required this.label, required this.count});

  final String label;
  final int count;
}

class _FrequencyList extends StatelessWidget {
  const _FrequencyList({required this.items});

  final List<_FrequencyItem> items;

  @override
  Widget build(BuildContext context) {
    final maximum = items.fold<int>(
      0,
      (current, item) => item.count > current ? item.count : current,
    );
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(height: 14),
          _FrequencyBar(
            label: items[index].label,
            count: items[index].count,
            maximum: maximum,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Text('${index + 1}'),
            ),
          ),
        ],
      ],
    );
  }
}

class _EnumFrequencyList<T> extends StatelessWidget {
  const _EnumFrequencyList({
    required this.counts,
    required this.labels,
    required this.emptyText,
  });

  final Map<T, int> counts;
  final Map<T, String> labels;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) {
      return _InlineEmptyState(text: emptyText);
    }

    final maximum = counts.values.fold<int>(
      0,
      (current, count) => count > current ? count : current,
    );
    final entries = counts.entries.toList(growable: false);
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          if (index > 0) const SizedBox(height: 14),
          _FrequencyBar(
            label: labels[entries[index].key] ?? entries[index].key.toString(),
            count: entries[index].value,
            maximum: maximum,
          ),
        ],
      ],
    );
  }
}

class _FrequencyBar extends StatelessWidget {
  const _FrequencyBar({
    required this.label,
    required this.count,
    required this.maximum,
    this.leading,
  });

  final String label;
  final int count;
  final int maximum;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label)),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: maximum == 0 ? 0 : count / maximum,
                  minHeight: 8,
                  color: colors.primary,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyOverviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.secondaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.spa_outlined, color: colors.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sobald du Zykluseinträge erfasst, erscheinen hier deine '
                'persönlichen Auswertungen.',
                style: TextStyle(color: colors.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
