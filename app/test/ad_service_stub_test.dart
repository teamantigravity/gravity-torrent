import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/services/ads/ad_service_stub.dart';

void main() {
  test('AdServiceStub never shows ads', () async {
    final ads = AdServiceStub();
    await ads.init();
    expect(ads.canShowAds, isFalse);
    expect(ads.buildBanner(), isNull);
    ads.showInterstitialIfReady();
  });
}
