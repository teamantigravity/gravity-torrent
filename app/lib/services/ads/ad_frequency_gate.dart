/// Enforces a shared minimum interval between full-screen ad impressions.
///
/// App-open and interstitial ads use the same gate so switching ad formats
/// cannot bypass the frequency limit.
class FullScreenAdFrequencyGate {
  FullScreenAdFrequencyGate({
    this.minimumInterval = const Duration(hours: 4),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (minimumInterval.isNegative) {
      throw ArgumentError.value(minimumInterval, 'minimumInterval');
    }
  }

  final Duration minimumInterval;
  final DateTime Function() _clock;
  DateTime? _lastShownAt;

  DateTime? get lastShownAt => _lastShownAt;

  bool get canShow {
    final lastShownAt = _lastShownAt;
    return lastShownAt == null ||
        _clock().difference(lastShownAt) >= minimumInterval;
  }

  void restore(DateTime? lastShownAt) {
    _lastShownAt = lastShownAt;
  }

  DateTime markShown() {
    final shownAt = _clock();
    _lastShownAt = shownAt;
    return shownAt;
  }
}
