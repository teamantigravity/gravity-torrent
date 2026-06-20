import 'package:flutter/widgets.dart';
import 'package:gravity_torrent/services/ads/ad_service.dart';

/// No-op ad implementation for web, desktop, and unsupported targets.
class AdServiceStub implements AdService {
  @override
  Future<void> init() async {}

  @override
  bool get isInitialized => true;

  @override
  bool get isAdFree => true;

  @override
  bool get canShowAds => false;

  @override
  Future<void> setAdFree(bool value) async {}

  @override
  Widget? buildBanner({Key? key}) => null;

  @override
  void showInterstitialIfReady() {}

  @override
  void dispose() {}
}

AdService createAdService() => AdServiceStub();
