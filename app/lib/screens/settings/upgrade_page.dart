import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:gravity_torrent/services/purchase/purchase_service.dart';
import 'package:gravity_torrent/services/purchase/purchase_service_provider.dart';

class UpgradePage extends StatefulWidget {
  const UpgradePage({super.key});

  @override
  State<UpgradePage> createState() => _UpgradePageState();
}

class _UpgradePageState extends State<UpgradePage> {
  final _purchase = PurchaseServiceProvider.instance;
  ProductDetailsInfo? _product;
  bool _loading = true;
  bool _purchasing = false;
  String? _error;
  bool _alreadyOwned = false;

  @override
  void initState() {
    super.initState();
    AdServiceProvider.instance.adFreeNotifier.addListener(_onAdFreeChanged);
    _load();
  }

  @override
  void dispose() {
    AdServiceProvider.instance.adFreeNotifier.removeListener(_onAdFreeChanged);
    super.dispose();
  }

  void _onAdFreeChanged() {
    if (!mounted) return;
    setState(() {
      _alreadyOwned = AdServiceProvider.instance.isAdFree;
    });
  }

  Future<void> _load() async {
    _alreadyOwned = AdServiceProvider.instance.isAdFree;
    if (_alreadyOwned) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!_purchase.isStoreSupported) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    final product = await _purchase.fetchRemoveAdsProduct();
    if (!mounted) return;
    setState(() {
      _product = product;
      _loading = false;
      _error = product == null ? 'storeUnavailable' : null;
    });
  }

  Future<void> _buy() async {
    setState(() => _purchasing = true);
    try {
      await _purchase.buyRemoveAds();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.purchaseFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    await _purchase.restorePurchases();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _alreadyOwned = AdServiceProvider.instance.isAdFree;
    });
    if (_alreadyOwned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.adsRemovedThankYou),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.removeAds)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.rocket_launch_outlined,
                size: 72,
                color: scheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.premiumTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.premiumSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              if (_alreadyOwned)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.check_circle, color: scheme.primary),
                    title: Text(l10n.alreadyPremium),
                  ),
                )
              else ...[
                _featureRow(
                  context,
                  l10n.premiumNoBanner,
                  Icons.hide_image_outlined,
                ),
                _featureRow(context, l10n.premiumNoInterstitial, Icons.block),
                _featureRow(
                  context,
                  l10n.premiumSupportDev,
                  Icons.favorite_outline,
                ),
              ],
              const Spacer(),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_alreadyOwned)
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.done),
                )
              else if (!_purchase.isStoreSupported)
                Text(
                  l10n.storeNotSupportedOnPlatform,
                  textAlign: TextAlign.center,
                )
              else if (_error != null)
                Text(l10n.storeUnavailable, textAlign: TextAlign.center)
              else
                FilledButton(
                  onPressed: _purchasing ? null : _buy,
                  child: _purchasing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('${l10n.removeAds} — ${_product?.price ?? ''}'),
                ),
              if (!_alreadyOwned && _purchase.isStoreSupported) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _restore,
                  child: Text(l10n.restorePurchase),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(BuildContext context, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
