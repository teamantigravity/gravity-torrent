import 'dart:async';

import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:gravity_torrent/services/purchase/purchase_service.dart';
import 'package:gravity_torrent/services/purchase/purchase_service_stub.dart'
    if (dart.library.html) 'package:gravity_torrent/services/purchase/purchase_service_stub.dart'
    if (dart.library.io) 'package:gravity_torrent/services/purchase/purchase_service_mobile.dart'
    as purchase_impl;

class PurchaseServiceProvider {
  PurchaseServiceProvider._();

  static final PurchaseService instance = purchase_impl.createPurchaseService();

  static void wirePurchaseStream() {
    instance.purchaseUpdates.listen(_handlePurchases);
  }

  static Future<void> _handlePurchases(List<PurchaseUpdate> updates) async {
    for (final update in updates) {
      if (update.productId != kRemoveAdsProductId) continue;
      switch (update.status) {
        case PurchaseUpdateStatus.purchased:
        case PurchaseUpdateStatus.restored:
          await AdServiceProvider.instance.setAdFree(true);
          await instance.completePurchase(update);
        case PurchaseUpdateStatus.pending:
          break;
        case PurchaseUpdateStatus.cancelled:
        case PurchaseUpdateStatus.failed:
        case PurchaseUpdateStatus.unavailable:
          if (update.needsCompletion) {
            await instance.completePurchase(update);
          }
      }
    }
  }
}
