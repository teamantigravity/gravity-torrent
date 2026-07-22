import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/models/feature_flags.dart';
import 'package:gravity_torrent/services/app_lock_service.dart';
import 'package:gravity_torrent/widgets/window_title_bar.dart';
import 'package:gravity_torrent/utils/device.dart';

class PrivacyVaultScreen extends StatefulWidget {
  const PrivacyVaultScreen({super.key});

  @override
  State<PrivacyVaultScreen> createState() => _PrivacyVaultScreenState();
}

class _PrivacyVaultScreenState extends State<PrivacyVaultScreen> {
  bool _loaded = false;
  bool _biometricsAvailable = false;
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AppLockService.instance.load();
    _biometricsAvailable = await AppLockService.instance.canUseBiometrics();
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _setPin() async {
    final localizations = AppLocalizations.of(context)!;
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.pinTooShort)),
        );
      }
      return;
    }
    try {
      await AppLockService.instance.setPin(pin);
      _pinController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(localizations.pinSaved)));
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.pinSaveFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    final localizations = AppLocalizations.of(context)!;
    if (value && !AppLockService.instance.hasPin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.pinRequiredBeforeLock)),
        );
      }
      return;
    }

    final flags = Provider.of<FeatureFlagsModel>(context, listen: false);
    await flags.setEnableAppLock(value);

    // Note: we intentionally keep the PIN in secure storage when the lock is
    // disabled. The hash is inert without the lock being active, and preserving
    // it lets the user re-enable lock without having to set a new PIN each time.

    if (mounted) setState(() {});
  }

  Future<void> _toggleUseBiometrics(bool value) async {
    await AppLockService.instance.setUseBiometrics(value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final lock = AppLockService.instance;
    final flags = Provider.of<FeatureFlagsModel>(context);

    return Scaffold(
      appBar: isDesktop()
          ? const WindowTitleBar()
          : AppBar(title: Text(localizations.privacyVault)),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  localizations.privacyVault,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.privacyVaultDescription,
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline),
                  title: Text(localizations.appLock),
                  subtitle: flags.isRemotelyDisabled('enableAppLock')
                      ? Text(
                          localizations.disabledByRemoteConfig,
                          style: const TextStyle(color: Colors.orange),
                        )
                      : Text(localizations.appLockDescription),
                  value: flags.enableAppLock,
                  onChanged: _toggleAppLock,
                ),
                if (flags.enableAppLock) ...[
                  if (_biometricsAvailable)
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint),
                      title: Text(localizations.biometricUnlock),
                      subtitle: Text(localizations.biometricUnlockDescription),
                      value: lock.useBiometrics,
                      onChanged: _toggleUseBiometrics,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 8,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: localizations.backupPin,
                        hintText: localizations.backupPinHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: FilledButton(
                      onPressed: _setPin,
                      child: Text(localizations.savePin),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  localizations.privacyScore,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _PrivacyScoreCard(score: _calculateScore(lock, flags)),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  int _calculateScore(AppLockService lock, FeatureFlagsModel flags) {
    int score = 70;
    if (flags.enableAppLock) score += 20;
    if (_biometricsAvailable) score += 10;
    return score.clamp(0, 100);
  }
}

class _PrivacyScoreCard extends StatelessWidget {
  final int score;

  const _PrivacyScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final color = score >= 90
        ? Colors.green
        : score >= 70
            ? Colors.orange
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.shield, color: color, size: 48),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$score/100',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  score >= 90
                      ? localizations.privacyScoreExcellent
                      : score >= 70
                          ? localizations.privacyScoreGood
                          : localizations.privacyScoreNeedsAttention,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
