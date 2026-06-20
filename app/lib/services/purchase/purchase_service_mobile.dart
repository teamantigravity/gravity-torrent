import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:gravity_torrent/services/purchase/purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseServiceMobile implements PurchaseService {
  PurchaseServiceMobile() {
    _subscription = InAppPurchase.instance.purchaseStream.listen(_onRawPurchases);
  }

  static const _adFreeKey = 'gravity_torrent_ad_free';
  final InAppPurchase _iap = InAppPurchase.instance;
  // Keeps the store purchase listener alive for the app lifetime.
  // ignore: unused_field
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  final _updates = StreamController<List<PurchaseUpdate>>.broadcast();

  @override
  Stream<List<PurchaseUpdate>> get purchaseUpdates => _updates.stream;

  @override
  bool get isStoreSupported {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  Future<bool> isAvailable() async {
    if (!isStoreSupported) return false;
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ProductDetailsInfo?> fetchRemoveAdsProduct() async {
    if (!await isAvailable()) return null;
    final response = await _iap.queryProductDetails({kRemoveAdsProductId});
    if (response.error != null || response.productDetails.isEmpty) return null;
    final product = response.productDetails.first;
    return ProductDetailsInfo(
      id: product.id,
      title: product.title,
      price: product.price,
    );
  }

  @override
  Future<void> buyRemoveAds() async {
    final product = await fetchRemoveAdsProduct();
    if (product == null) return;
    final details = (await _iap.queryProductDetails({kRemoveAdsProductId}))
        .productDetails
        .first;
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  @override
  Future<void> restorePurchases() async {
    if (!await isAvailable()) return;
    await _iap.restorePurchases();
  }

  @override
  Future<void> completePurchase(PurchaseUpdate update) async {
    final token = update.purchaseToken;
    if (token is! PurchaseDetails) return;
    if (token.pendingCompletePurchase) {
      await _iap.completePurchase(token);
    }
  }

  @override
  Future<bool> hasLocalAdFreeEntitlement() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adFreeKey) ?? false;
  }

  void _onRawPurchases(List<PurchaseDetails> purchases) {
    final mapped = purchases.map(_mapPurchase).toList();
    _updates.add(mapped);
  }

  PurchaseUpdate _mapPurchase(PurchaseDetails p) {
    final status = switch (p.status) {
      PurchaseStatus.pending => PurchaseUpdateStatus.pending,
      PurchaseStatus.purchased => PurchaseUpdateStatus.purchased,
      PurchaseStatus.restored => PurchaseUpdateStatus.restored,
      PurchaseStatus.canceled => PurchaseUpdateStatus.cancelled,
      PurchaseStatus.error => PurchaseUpdateStatus.failed,
    };

    return PurchaseUpdate(
      productId: p.productID,
      status: status,
      errorMessage: p.error?.message,
      needsCompletion: p.pendingCompletePurchase,
      purchaseToken: p,
    );
  }

  Future<void> syncEntitlementOnStartup() async {
    if (await hasLocalAdFreeEntitlement()) {
      await AdServiceProvider.instance.setAdFree(true);
    }
  }
}

PurchaseService createPurchaseService() {
  final service = PurchaseServiceMobile();
  unawaited(service.syncEntitlementOnStartup());
  return service;
}
