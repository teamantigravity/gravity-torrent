import 'package:gravity_torrent/services/ads/ad_service.dart';
import 'package:gravity_torrent/services/ads/ad_service_stub.dart'
    if (dart.library.html) 'package:gravity_torrent/services/ads/ad_service_stub.dart'
    if (dart.library.io) 'package:gravity_torrent/services/ads/ad_service_mobile.dart'
    as ad_impl;

/// Singleton accessor — resolves to stub on web and mobile impl on IO targets.
class AdServiceProvider {
  AdServiceProvider._();

  static final AdService instance = ad_impl.createAdService();
}
