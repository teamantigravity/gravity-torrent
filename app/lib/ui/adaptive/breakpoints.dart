import 'package:flutter/material.dart';

/// Material 3 adaptive breakpoints used by the app's responsive layout.
///
/// - small: phone / compact window (< 600dp)
/// - medium: tablet / small tablet / medium window (600dp - 840dp)
/// - large: desktop / expanded window (> 840dp)
abstract class AdaptiveBreakpoints {
  static const smallEnd = 600.0;
  static const mediumEnd = 840.0;
  static const largeEnd = 1200.0;

  static double _width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// True when the window is in compact (phone) range.
  static bool isCompact(BuildContext context) => _width(context) < smallEnd;

  /// True when the window is in medium (small tablet) range.
  static bool isMedium(BuildContext context) =>
      _width(context) >= smallEnd && _width(context) < mediumEnd;

  /// True when the window is in expanded (tablet / small desktop) range.
  static bool isExpanded(BuildContext context) =>
      _width(context) >= mediumEnd && _width(context) < largeEnd;

  /// True when the window is in large (desktop) range.
  static bool isLarge(BuildContext context) => _width(context) >= largeEnd;

  /// True when the app should switch from a bottom navigation bar to a
  /// navigation rail / side navigation.
  static bool useNavigationRail(BuildContext context) =>
      _width(context) >= smallEnd;
}
