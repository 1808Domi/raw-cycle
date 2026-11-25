import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.onComplete, super.key});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _pages = [
    _OnboardingContent(
      title: 'Willkommen',
      description:
          'Lerne deinen Zyklus besser kennen – mit einem liebevollen Blick '
          'auf dein tägliches Wohlbefinden.',
      icon: Icons.favorite_rounded,
      color: Color(0xFFCC829A),
    ),
    _OnboardingContent(
      title: 'Intelligente Vorhersagen',
      description:
          'Mit deinen Einträgen schätzt Raw Cycle kommende Perioden und '
          'Zyklusphasen ein. Je mehr du erfasst, desto persönlicher werden '
          'deine Einblicke.',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF8874B8),
    ),
    _OnboardingContent(
      title: 'Datenschutz',
      description:
          'Deine Zyklusdaten bleiben lokal auf deinem Gerät. Du behältst '
          'die Kontrolle und kannst jederzeit ein Backup erstellen.',
      icon: Icons.lock_rounded,
      color: Color(0xFF6D9E8B),
    ),
    _OnboardingContent(
      title: "Los geht's",
      description:
          'Alles ist bereit. Starte jetzt und halte fest, was für dich '
          'wichtig ist – ganz in deinem Tempo.',
      icon: Icons.spa_rounded,
      color: Color(0xFFCC829A),
    ),
  ];

  final _pageController = PageController();
  int _currentPage = 0;
  bool _isFinishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_isFinishing) {
      return;
    }

    setState(() {
      _isFinishing = true;
    });

    try {
      await widget.onComplete();
    } catch (error, stackTrace) {
      debugPrint('Could not complete onboarding: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Onboarding konnte nicht gespeichert werden. Bitte versuche es '
              'erneut.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFinishing = false;
        });
      }
    }
  }

  Future<void> _continue() async {
    if (_currentPage == _pages.length - 1) {
      await _finish();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Raw Cycle',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isFinishing ? null : _finish,
                    child: const Text('Überspringen'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) =>
                    _OnboardingPageContent(content: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (var index = 0; index < _pages.length; index++) ...[
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 5,
                            decoration: BoxDecoration(
                              color: index <= _currentPage
                                  ? colors.primary
                                  : colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        if (index < _pages.length - 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_currentPage + 1} von ${_pages.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _isFinishing ? null : _continue,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _isFinishing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _currentPage == _pages.length - 1
                                  ? 'Raw Cycle starten'
                                  : 'Weiter',
                            ),
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

class _OnboardingContent {
  const _OnboardingContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

class _OnboardingPageContent extends StatelessWidget {
  const _OnboardingPageContent({required this.content});

  final _OnboardingContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 196,
              height: 196,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: content.color.withValues(alpha: 0.13),
              ),
              child: Center(
                child: Container(
                  width: 144,
                  height: 144,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: content.color.withValues(alpha: 0.2),
                  ),
                  child: Icon(content.icon, size: 76, color: content.color),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              content.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                content.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.55,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
