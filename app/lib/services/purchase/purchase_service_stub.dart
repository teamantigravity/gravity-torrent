import 'dart:async';

import 'package:gravity_torrent/services/purchase/purchase_service.dart';

class PurchaseServiceStub implements PurchaseService {
  final _controller = StreamController<List<PurchaseUpdate>>.broadcast();

  @override
  Stream<List<PurchaseUpdate>> get purchaseUpdates => _controller.stream;

  @override
  bool get isStoreSupported => false;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ProductDetailsInfo?> fetchRemoveAdsProduct() async => null;

  @override
  Future<void> buyRemoveAds() async {}

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> completePurchase(PurchaseUpdate update) async {}

  @override
  Future<bool> hasLocalAdFreeEntitlement() async => false;

  @override
  void dispose() {
    _controller.close();
  }
}

PurchaseService createPurchaseService() => PurchaseServiceStub();
