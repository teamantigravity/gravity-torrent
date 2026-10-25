import 'package:flutter/widgets.dart';

/// Platform-agnostic ad surface contract. Implementations must never throw.
abstract class AdService {
  Future<void> init();

  bool get isInitialized;
  bool get isAdFree;
  ValueNotifier<bool> get adFreeNotifier;
  bool get canShowAds;

  Future<void> setAdFree(bool value);

  /// Optional banner widget; returns null when ads are disabled or unavailable.
  Widget? buildBanner({Key? key});

  /// Notify only after a user-initiated addition succeeds and its dialog closes.
  /// The service decides whether this completed task is an eligible ad break.
  void onTorrentAdded();

  /// Suppress full-screen ads during playback or another critical flow.
  /// The returned release callback is idempotent; overlapping scopes compose.
  VoidCallback suppressFullScreenAds();

  void dispose();
}
