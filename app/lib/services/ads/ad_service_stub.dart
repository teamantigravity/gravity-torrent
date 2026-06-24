import 'package:flutter/widgets.dart';
import 'package:gravity_torrent/services/ads/ad_service.dart';

/// No-op ad implementation for web, desktop, and unsupported targets.
class AdServiceStub implements AdService {
  final ValueNotifier<bool> _adFreeNotifier = ValueNotifier<bool>(true);

  @override
  Future<void> init() async {}

  @override
  bool get isInitialized => true;

  @override
  bool get isAdFree => _adFreeNotifier.value;

  @override
  ValueNotifier<bool> get adFreeNotifier => _adFreeNotifier;

  @override
  bool get canShowAds => false;

  @override
  Future<void> setAdFree(bool value) async {
    _adFreeNotifier.value = value;
  }

  @override
  Widget? buildBanner({Key? key}) => null;

  @override
  void showInterstitialIfReady() {}

  @override
  void dispose() {
    _adFreeNotifier.dispose();
  }
}

AdService createAdService() => AdServiceStub();
