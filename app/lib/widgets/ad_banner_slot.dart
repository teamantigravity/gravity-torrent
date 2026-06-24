import 'package:flutter/material.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';

/// Non-blocking footer banner. Renders nothing when ads are unavailable.
class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({super.key});

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  @override
  void initState() {
    super.initState();
    AdServiceProvider.instance.adFreeNotifier.addListener(_onAdFreeChanged);
  }

  @override
  void dispose() {
    AdServiceProvider.instance.adFreeNotifier.removeListener(_onAdFreeChanged);
    super.dispose();
  }

  void _onAdFreeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (AdServiceProvider.instance.isAdFree) return const SizedBox.shrink();
    
    final banner = AdServiceProvider.instance.buildBanner();
    if (banner == null) return const SizedBox.shrink();
    
    return SafeArea(
      top: false,
      child: Material(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Center(child: banner),
      ),
    );
  }
}
