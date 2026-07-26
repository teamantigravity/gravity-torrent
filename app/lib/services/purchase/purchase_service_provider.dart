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

  static StreamSubscription<List<PurchaseUpdate>>? _purchaseSub;

  static bool _disposed = false;

  static void wirePurchaseStream() {
    if (_disposed) return;
    _purchaseSub?.cancel();
    _purchaseSub = instance.purchaseUpdates.listen(_handlePurchases);
  }

  static Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    instance.dispose();
  }

  static Future<void> _handlePurchases(List<PurchaseUpdate> updates) async {
    if (_disposed) return;
    for (final update in updates) {
      if (_disposed) return;
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
