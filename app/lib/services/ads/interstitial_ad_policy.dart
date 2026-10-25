/// Interstitial eligibility at a completed, user-initiated add-torrent task.
///
/// The first app launch is full-screen-ad free. Later launches allow at most
/// one presentation attempt, after two successful additions. Loading an ad
/// never creates an opportunity: a missed break waits for another completed
/// task. Background completions do not count.
///
/// See docs/ad-policy.md for the placement research and product decisions.
class InterstitialAdPolicy {
  InterstitialAdPolicy({required this.isFirstSession});

  final bool isFirstSession;
  static const minimumCompletedTasks = 2;
  int _completedTasks = 0;
  bool _presentationAttempted = false;

  bool get canRequestAd => !isFirstSession && !_presentationAttempted;

  /// Records a genuine successful addition and atomically reserves the single
  /// presentation attempt when an ad is already ready at that task boundary.
  bool onTorrentAdded({required bool adReady, required bool isForeground}) {
    if (!canRequestAd || !isForeground) return false;
    if (_completedTasks < minimumCompletedTasks) _completedTasks++;
    if (_completedTasks < minimumCompletedTasks || !adReady) return false;
    _presentationAttempted = true;
    return true;
  }
}
