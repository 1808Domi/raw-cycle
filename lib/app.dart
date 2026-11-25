import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/app_protection/data/pin_credential_service.dart';
import 'features/app_protection/presentation/app_lock_page.dart';
import 'features/navigation/presentation/main_navigation.dart';
import 'features/onboarding/data/onboarding_service.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'features/settings/data/settings_service.dart';

class RawCycleApp extends StatefulWidget {
  const RawCycleApp({
    @visibleForTesting this.pinCredentials,
    @visibleForTesting this.authenticator,
    super.key,
  });

  @visibleForTesting
  final PinCredentialRepository? pinCredentials;

  @visibleForTesting
  final Future<bool> Function(AppProtectionMethod method)? authenticator;

  @override
  State<RawCycleApp> createState() => _RawCycleAppState();
}

class _RawCycleAppState extends State<RawCycleApp> with WidgetsBindingObserver {
  late bool _hasCompletedOnboarding;
  late Future<CycleSettings> _settingsFuture;
  CycleSettings? _settings;
  StreamSubscription<CycleSettings>? _settingsSubscription;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hasCompletedOnboarding = OnboardingService.instance.hasCompletedOnboarding;
    _settingsFuture = _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = _settings;
    if (state == AppLifecycleState.paused &&
        _isAuthenticated &&
        settings?.appProtectionEnabled == true &&
        settings?.appProtectionCheckMode ==
            AppProtectionCheckMode.afterInactivity) {
      setState(() {
        _isAuthenticated = false;
      });
    }
  }

  Future<CycleSettings> _loadSettings() async {
    final service = SettingsService.instance;
    if (!service.isInitialized) {
      await service.init();
    }
    final settings = await service.load();
    _settings = settings;
    _settingsSubscription = service.watch().listen(
      _updateSettings,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Could not observe app protection settings: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
    return settings;
  }

  void _updateSettings(CycleSettings settings) {
    if (!mounted) {
      return;
    }
    final previousSettings = _settings;
    final protectionChanged =
        settings.appProtectionEnabled &&
        (previousSettings?.appProtectionEnabled != true ||
            previousSettings?.appProtectionMethod !=
                settings.appProtectionMethod);
    setState(() {
      _settings = settings;
      if (protectionChanged) {
        _isAuthenticated = false;
      }
    });
  }

  Future<void> _completeOnboarding() async {
    await OnboardingService.instance.markCompleted();
    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = true;
      });
    }
  }

  void _onAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raw Cycle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: !_hasCompletedOnboarding
          ? OnboardingPage(onComplete: _completeOnboarding)
          : FutureBuilder<CycleSettings>(
              future: _settingsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'App-Schutz-Einstellungen konnten nicht geladen '
                          'werden: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }
                final settings = snapshot.data;
                if (settings == null) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!settings.appProtectionEnabled || _isAuthenticated) {
                  return const MainNavigation();
                }
                return AppLockPage(
                  settings: settings,
                  onAuthenticated: _onAuthenticated,
                  pinCredentials: widget.pinCredentials,
                  authenticate: widget.authenticator,
                );
              },
            ),
    );
  }
}
