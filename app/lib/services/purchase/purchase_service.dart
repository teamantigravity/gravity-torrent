/// Non-consumable remove-ads product ID (Play Console / App Store Connect).
const String kRemoveAdsProductId = 'gravitytorrent_remove_ads';

enum PurchaseUpdateStatus {
  pending,
  purchased,
  restored,
  cancelled,
  failed,
  unavailable,
}

class PurchaseUpdate {
  const PurchaseUpdate({
    required this.productId,
    required this.status,
    this.errorMessage,
    this.needsCompletion = false,
    this.purchaseToken,
  });

  final String productId;
  final PurchaseUpdateStatus status;
  final String? errorMessage;
  final bool needsCompletion;
  final Object? purchaseToken;
}

class ProductDetailsInfo {
  const ProductDetailsInfo({
    required this.id,
    required this.title,
    required this.price,
  });

  final String id;
  final String title;
  final String price;
}

abstract class PurchaseService {
  Stream<List<PurchaseUpdate>> get purchaseUpdates;

  bool get isStoreSupported;

  Future<bool> isAvailable();

  Future<ProductDetailsInfo?> fetchRemoveAdsProduct();

  Future<void> buyRemoveAds();

  Future<void> restorePurchases();

  Future<void> completePurchase(PurchaseUpdate update);

  Future<bool> hasLocalAdFreeEntitlement();

  void dispose();
}
