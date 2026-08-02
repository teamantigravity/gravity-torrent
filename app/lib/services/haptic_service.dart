import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gravity_torrent/utils/device.dart';

/// Mobile haptic feedback helper.
///
/// Uses [HapticFeedback] on Android/iOS when enabled. Desktop and web targets
/// do not expose haptic APIs through this abstraction, so calls are ignored
/// there.
class HapticService {
  static bool _enabled = true;

  static void setEnabled(bool value) => _enabled = value;

  static void _feedback(Future<void> Function() action) {
    if (!_enabled || !isMobile()) return;
    unawaited(
      action().catchError((Object e) {
        if (kDebugMode) debugPrint('HapticService feedback error: $e');
      }),
    );
  }

  static void light() => _feedback(HapticFeedback.lightImpact);

  static void medium() => _feedback(HapticFeedback.mediumImpact);

  static void heavy() => _feedback(HapticFeedback.heavyImpact);

  static void selection() => _feedback(HapticFeedback.selectionClick);
}
