import 'package:flutter/material.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';

/// Non-blocking footer banner. Renders nothing when ads are unavailable.
class AdBannerSlot extends StatelessWidget {
  const AdBannerSlot({super.key});

  @override
  Widget build(BuildContext context) {
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
