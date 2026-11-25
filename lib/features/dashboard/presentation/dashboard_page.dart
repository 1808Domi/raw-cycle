import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/cycle_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.cycleService});

  @visibleForTesting
  final CycleService? cycleService;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  static const _rose = Color(0xFFCC829A);
  static const _mint = Color(0xFF6D9E8B);

  late Future<_DashboardCycleData> _cycleDataFuture;
  late CycleService _cycleService;
  late final AnimationController _cardEntranceController;
  late final AnimationController _progressAnimationController;
  late final CurvedAnimation _progressAnimation;
  late final CurvedAnimation _periodCardEntrance;
  late final CurvedAnimation _ovulationCardEntrance;
  late final CurvedAnimation _phaseCardEntrance;
  Future<_DashboardCycleData>? _animatedCycleDataFuture;
  StreamSubscription<void>? _changesSubscription;

  @override
  void initState() {
    super.initState();
    _cardEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOutCubic,
    );
    _periodCardEntrance = _createCardEntrance(0, 0.55);
    _ovulationCardEntrance = _createCardEntrance(0.18, 0.73);
    _phaseCardEntrance = _createCardEntrance(0.36, 0.91);
    _configureCycleService();
  }

  CurvedAnimation _createCardEntrance(double start, double end) {
    return CurvedAnimation(
      parent: _cardEntranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cycleService != widget.cycleService) {
      _configureCycleService();
    }
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    _progressAnimation.dispose();
    _progressAnimationController.dispose();
    _periodCardEntrance.dispose();
    _ovulationCardEntrance.dispose();
    _phaseCardEntrance.dispose();
    _cardEntranceController.dispose();
    super.dispose();
  }

  void _configureCycleService() {
    _changesSubscription?.cancel();
    _cycleService = widget.cycleService ?? CycleService.instance;
    _progressAnimationController.reset();
    _animatedCycleDataFuture = null;
    _cycleDataFuture = _loadCycleData(_cycleService);

    _changesSubscription = _cycleService.entryChanges?.listen(
      (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _progressAnimationController.reset();
          _animatedCycleDataFuture = null;
          _cycleDataFuture = _loadCycleData(_cycleService);
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) {
          return;
        }
        setState(() {
          _cycleDataFuture = Future<_DashboardCycleData>.error(
            error,
            stackTrace,
          );
        });
      },
    );
  }

  Future<_DashboardCycleData> _loadCycleData(CycleService cycleService) async {
    final (
      daysUntilNextPeriod,
      daysUntilOvulation,
      phase,
      phaseDescription,
      hasSufficientData,
      averageCycleLength,
      currentCycleDay,
    ) = await (
      cycleService.getDaysUntilNextPeriod(),
      cycleService.getDaysUntilOvulation(),
      cycleService.getCurrentCyclePhase(),
      cycleService.getPhaseDescription(),
      cycleService.hasSufficientDataForPredictions(),
      cycleService.getAverageCycleLength(),
      cycleService.getCurrentCycleDay(),
    ).wait;

    return _DashboardCycleData(
      daysUntilNextPeriod: daysUntilNextPeriod,
      daysUntilOvulation: daysUntilOvulation,
      phase: phase,
      phaseDescription: phaseDescription,
      hasSufficientData: hasSufficientData,
      averageCycleLength: averageCycleLength,
      currentCycleDay: currentCycleDay,
    );
  }

  void _startProgressAnimationWhenLoaded(
    AsyncSnapshot<_DashboardCycleData> snapshot,
  ) {
    if (snapshot.connectionState != ConnectionState.done ||
        !snapshot.hasData ||
        identical(_animatedCycleDataFuture, _cycleDataFuture)) {
      return;
    }

    final future = _cycleDataFuture;
    _animatedCycleDataFuture = future;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(future, _cycleDataFuture)) {
        _progressAnimationController.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = switch (hour) {
      < 12 => 'Guten Morgen',
      < 18 => 'Guten Tag',
      _ => 'Guten Abend',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          greeting,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Schön, dass du da bist.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FutureBuilder<_DashboardCycleData>(
          future: _cycleDataFuture,
          builder: (context, snapshot) {
            _startProgressAnimationWhenLoaded(snapshot);
            final cycleData = snapshot.data;
            final hasInsufficientData =
                cycleData == null ||
                cycleData.daysUntilNextPeriod == null ||
                cycleData.daysUntilOvulation == null ||
                cycleData.phase == CyclePhase.unknown ||
                !cycleData.hasSufficientData;
            final progressAvailable =
                !snapshot.hasError && !hasInsufficientData;

            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _StaggeredCardEntrance(
                        key: const ValueKey('period-card-entrance'),
                        animation: _periodCardEntrance,
                        child: _CycleProgressCard(
                          title: 'Nächste Periode',
                          progress: progressAvailable
                              ? _progressForCycle(cycleData)
                              : null,
                          progressAnimation: _progressAnimation,
                          remainingDaysText: _remainingDaysText(
                            snapshot,
                            cycleData?.daysUntilNextPeriod,
                          ),
                          caption: 'Tage',
                          accentColor: AppTheme.lavender,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StaggeredCardEntrance(
                        key: const ValueKey('ovulation-card-entrance'),
                        animation: _ovulationCardEntrance,
                        child: _CycleProgressCard(
                          title: 'Nächster Eisprung',
                          progress: progressAvailable
                              ? _progressUntilOvulation(cycleData)
                              : null,
                          progressAnimation: _progressAnimation,
                          remainingDaysText: _remainingDaysText(
                            snapshot,
                            cycleData?.daysUntilOvulation,
                          ),
                          caption: 'Tage',
                          accentColor: _rose,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _StaggeredCardEntrance(
                  key: const ValueKey('phase-card-entrance'),
                  animation: _phaseCardEntrance,
                  child: _CyclePhaseCard(
                    accentColor: _mint,
                    phaseTitle: _phaseTitle(cycleData?.phase),
                    description: _phaseDescription(
                      snapshot,
                      cycleData,
                      hasInsufficientData,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _remainingDaysText(
    AsyncSnapshot<_DashboardCycleData> snapshot,
    int? days,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return '';
    }
    if (snapshot.hasError || days == null) {
      return '';
    }
    return '$days';
  }

  double? _progressForCycle(_DashboardCycleData? data) {
    final cycleDay = data?.currentCycleDay;
    if (data == null || cycleDay == null) {
      return null;
    }
    if (data.daysUntilNextPeriod == 0) {
      return 1;
    }

    return (cycleDay / data.averageCycleLength).clamp(0.0, 1.0).toDouble();
  }

  double? _progressUntilOvulation(_DashboardCycleData? data) {
    final cycleDay = data?.currentCycleDay;
    if (data == null || cycleDay == null) {
      return null;
    }
    if (data.daysUntilOvulation == 0) {
      return 1;
    }

    final ovulationDay = data.averageCycleLength > 14
        ? data.averageCycleLength - 14
        : 1;
    return (cycleDay / ovulationDay).clamp(0.0, 1.0).toDouble();
  }

  String _phaseTitle(CyclePhase? phase) {
    if (phase == null || phase == CyclePhase.unknown) {
      return 'Noch nicht verfügbar';
    }
    return switch (phase) {
      CyclePhase.menstruation => 'Menstruation',
      CyclePhase.follicular => 'Follikelphase',
      CyclePhase.fertile => 'Fruchtbare Phase',
      CyclePhase.ovulation => 'Eisprung',
      CyclePhase.luteal => 'Lutealphase',
      CyclePhase.unknown => 'Noch nicht verfügbar',
    };
  }

  String _phaseDescription(
    AsyncSnapshot<_DashboardCycleData> snapshot,
    _DashboardCycleData? cycleData,
    bool hasInsufficientData,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return 'Zyklusdaten werden geladen.';
    }
    if (snapshot.hasError) {
      return 'Zyklusdaten konnten nicht geladen werden: ${snapshot.error}';
    }
    if (hasInsufficientData) {
      return 'Für genaue Vorhersagen werden mehr Zyklusdaten benötigt.';
    }
    return cycleData!.phaseDescription;
  }
}

class _DashboardCycleData {
  const _DashboardCycleData({
    required this.daysUntilNextPeriod,
    required this.daysUntilOvulation,
    required this.phase,
    required this.phaseDescription,
    required this.hasSufficientData,
    required this.averageCycleLength,
    required this.currentCycleDay,
  });

  final int? daysUntilNextPeriod;
  final int? daysUntilOvulation;
  final CyclePhase phase;
  final String phaseDescription;
  final bool hasSufficientData;
  final int averageCycleLength;
  final int? currentCycleDay;
}

class _StaggeredCardEntrance extends StatelessWidget {
  const _StaggeredCardEntrance({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(animation);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

class _CycleProgressCard extends StatelessWidget {
  const _CycleProgressCard({
    required this.title,
    required this.progress,
    required this.progressAnimation,
    required this.remainingDaysText,
    required this.caption,
    required this.accentColor,
  });

  final String title;
  final double? progress;
  final Animation<double> progressAnimation;
  final String remainingDaysText;
  final String caption;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressValue = progress;

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 82,
              height: 82,
              child: AnimatedBuilder(
                animation: progressAnimation,
                builder: (context, _) {
                  final animatedProgress =
                      (progressValue ?? 0) * progressAnimation.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: animatedProgress,
                          strokeWidth: 7,
                          strokeCap: StrokeCap.butt,
                          backgroundColor: accentColor.withValues(alpha: 0.18),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                      ),
                      Text(
                        remainingDaysText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CyclePhaseCard extends StatelessWidget {
  const _CyclePhaseCard({
    required this.accentColor,
    required this.phaseTitle,
    required this.description,
  });

  final Color accentColor;
  final String phaseTitle;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.spa_rounded, color: accentColor, size: 27),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AKTUELLE ZYKLUSPHASE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: accentColor,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    phaseTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
