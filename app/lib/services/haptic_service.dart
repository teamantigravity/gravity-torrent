import 'package:flutter/services.dart';
import 'package:gravity_torrent/utils/device.dart';

/// Mobile haptic feedback helper.
///
/// Uses [HapticFeedback] on Android/iOS when enabled. Desktop targets do not
/// expose haptic APIs through this abstraction, so calls are ignored there.
class HapticService {
  static bool _enabled = true;

  static void setEnabled(bool value) => _enabled = value;

  static void light() {
    if (!_enabled || isDesktop()) return;
    HapticFeedback.lightImpact();
  }

  static void medium() {
    if (!_enabled || isDesktop()) return;
    HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (!_enabled || isDesktop()) return;
    HapticFeedback.heavyImpact();
  }

  static void selection() {
    if (!_enabled || isDesktop()) return;
    HapticFeedback.selectionClick();
  }
}
