import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../settings/data/settings_service.dart';
import '../data/pin_credential_service.dart';

class AppLockPage extends StatefulWidget {
  const AppLockPage({
    required this.settings,
    required this.onAuthenticated,
    this.pinCredentials,
    this.authenticate,
    super.key,
  });

  final CycleSettings settings;
  final VoidCallback onAuthenticated;
  final PinCredentialRepository? pinCredentials;
  final Future<bool> Function(AppProtectionMethod method)? authenticate;

  @override
  State<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends State<AppLockPage> with WidgetsBindingObserver {
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();

  late final PinCredentialRepository _pinCredentials;
  bool _isAuthenticating = false;
  bool _hasPin = true;
  bool _hasAttemptedAuthentication = false;
  String? _errorMessage;

  bool get _isPinMethod =>
      widget.settings.appProtectionMethod == AppProtectionMethod.pin;

  @override
  void initState() {
    super.initState();
    _pinCredentials = widget.pinCredentials ?? PinCredentialService.instance;
    WidgetsBinding.instance.addObserver(this);
    if (_isPinMethod) {
      unawaited(_checkPinConfiguration());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final lifecycleState = WidgetsBinding.instance.lifecycleState;
        if (mounted &&
            lifecycleState != AppLifecycleState.inactive &&
            lifecycleState != AppLifecycleState.paused) {
          unawaited(_authenticate());
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_isPinMethod &&
        !_hasAttemptedAuthentication) {
      unawaited(_authenticate());
    }
  }

  Future<void> _checkPinConfiguration() async {
    try {
      final hasPin = await _pinCredentials.isPinConfigured();
      if (mounted) {
        setState(() {
          _hasPin = hasPin;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Could not read the app PIN: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Die gespeicherte PIN konnte nicht geladen werden.';
        });
      }
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating || _isPinMethod || !mounted) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
      _hasAttemptedAuthentication = true;
    });

    try {
      final authenticate = widget.authenticate ?? _authenticateWithDevice;
      final succeeded = await authenticate(widget.settings.appProtectionMethod);
      if (!mounted) {
        return;
      }
      if (succeeded) {
        widget.onAuthenticated();
      } else {
        setState(() {
          _errorMessage =
              'Authentifizierung abgebrochen. Raw Cycle bleibt gesperrt.';
        });
      }
    } on LocalAuthException catch (error, stackTrace) {
      _showAuthenticationError(error, stackTrace);
    } on PlatformException catch (error, stackTrace) {
      _showAuthenticationError(error, stackTrace);
    } catch (error, stackTrace) {
      _showAuthenticationError(error, stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<bool> _authenticateWithDevice(AppProtectionMethod method) {
    return LocalAuthentication().authenticate(
      localizedReason: 'Entsperre Raw Cycle, um dein Dashboard zu öffnen.',
      biometricOnly: method == AppProtectionMethod.biometrics,
      persistAcrossBackgrounding: true,
    );
  }

  void _showAuthenticationError(Object error, StackTrace stackTrace) {
    debugPrint('App authentication failed: $error\n$stackTrace');
    if (mounted) {
      setState(() {
        _errorMessage = 'Authentifizierung nicht möglich: $error';
      });
    }
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text;
    if (!PinCredentialService.isValidPin(pin)) {
      setState(() {
        _errorMessage = 'Gib eine PIN mit 4 bis 12 Ziffern ein.';
      });
      return;
    }

    if (!_hasPin && pin != _confirmationController.text) {
      setState(() {
        _errorMessage = 'Die eingegebenen PINs stimmen nicht überein.';
      });
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      if (_hasPin) {
        final isValid = await _pinCredentials.verifyPin(pin);
        if (!isValid) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Die PIN ist nicht korrekt.';
            });
          }
          return;
        }
      } else {
        await _pinCredentials.setPin(pin);
      }

      if (mounted) {
        widget.onAuthenticated();
      }
    } catch (error, stackTrace) {
      debugPrint('PIN authentication failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Die PIN konnte nicht überprüft werden: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isSettingUpPin = _isPinMethod && !_hasPin;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Card(
                  color: colors.surfaceContainerLow,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primaryContainer,
                          ),
                          child: Icon(
                            _isPinMethod
                                ? Icons.pin_rounded
                                : Icons.lock_rounded,
                            size: 48,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isSettingUpPin
                              ? 'PIN einrichten'
                              : 'Raw Cycle entsperren',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isSettingUpPin
                              ? 'Für diese PIN-geschützte Sicherung ist noch '
                                    'keine PIN auf diesem Gerät eingerichtet.'
                              : 'Authentifiziere dich, um dein Dashboard zu '
                                    'öffnen.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        if (_isPinMethod) ...[
                          const SizedBox(height: 24),
                          TextField(
                            controller: _pinController,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 12,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: isSettingUpPin ? 'Neue PIN' : 'PIN',
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onSubmitted: (_) {
                              if (!_isAuthenticating) {
                                _submitPin();
                              }
                            },
                          ),
                          if (isSettingUpPin) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmationController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 12,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'PIN bestätigen',
                                counterText: '',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onSubmitted: (_) {
                                if (!_isAuthenticating) {
                                  _submitPin();
                                }
                              },
                            ),
                          ],
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _isAuthenticating
                                ? null
                                : _isPinMethod
                                ? _submitPin
                                : _authenticate,
                            icon: _isAuthenticating
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _isPinMethod
                                        ? Icons.lock_open_rounded
                                        : Icons.fingerprint_rounded,
                                  ),
                            label: Text(
                              _isAuthenticating
                                  ? 'Bitte warten'
                                  : isSettingUpPin
                                  ? 'PIN einrichten'
                                  : _isPinMethod
                                  ? 'Entsperren'
                                  : 'Erneut versuchen',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
