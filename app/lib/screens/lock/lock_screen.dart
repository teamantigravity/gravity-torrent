import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/app_lock_service.dart';

/// PIN / biometric unlock gate shown when app lock is enabled.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  bool _isLoading = true;
  bool _biometricsAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _biometricsAvailable = await AppLockService.instance.canUseBiometrics();
    if (!mounted) return;

    if (AppLockService.instance.useBiometrics && _biometricsAvailable) {
      await _tryBiometricUnlock();
    } else {
      setState(() {
        _isLoading = false;
        // If the user has biometrics enabled but none are enrolled on this
        // device, surface an explanatory message instead of silently showing
        // just the PIN prompt.
        if (AppLockService.instance.useBiometrics && !_biometricsAvailable) {
          _error = AppLocalizations.of(context)!.noBiometricsEnrolled;
        }
      });
    }
  }

  Future<void> _tryBiometricUnlock() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final ok = await AppLockService.instance.authenticateWithBiometrics();
      if (ok && mounted) {
        widget.onUnlocked();
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = AppLocalizations.of(context)!.biometricFailed;
      });
    }
  }

  Future<void> _unlockWithPin() async {
    final localizations = AppLocalizations.of(context)!;
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;

    try {
      final ok = await AppLockService.instance.authenticateWithPin(pin);
      if (ok && mounted) {
        widget.onUnlocked();
      } else if (mounted) {
        setState(() {
          _error = localizations.incorrectPin;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = localizations.incorrectPin;
        });
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = AppLocalizations.of(context)!;
    final showBiometricOption =
        AppLockService.instance.useBiometrics && _biometricsAvailable;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 72,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    localizations.appLockedTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    showBiometricOption
                        ? localizations.unlockWithBiometricsOrPin
                        : localizations.enterPinToContinue,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else ...[
                    if (showBiometricOption) ...[
                      Icon(
                        Icons.fingerprint,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _tryBiometricUnlock,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(localizations.useBiometrics),
                      ),
                      const SizedBox(height: 24),
                    ],
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 8,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _unlockWithPin(),
                      decoration: InputDecoration(
                        labelText: localizations.pin,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.pin),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(color: colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _unlockWithPin,
                        icon: const Icon(Icons.lock_open),
                        label: Text(localizations.unlock),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
