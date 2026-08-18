import 'package:flutter/material.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

class AccessibilityService extends ChangeNotifier {
  static const _keyHighContrast = 'a11y_high_contrast';
  static const _keyReducedMotion = 'a11y_reduced_motion';
  static const _keyLargeText = 'a11y_large_text';
  static const _keyBoldText = 'a11y_bold_text';

  bool _highContrast = false;
  bool _reducedMotion = false;
  bool _largeText = false;
  bool _boldText = false;
  bool _disposed = false;

  bool get highContrast => _highContrast;
  bool get reducedMotion => _reducedMotion;
  bool get largeText => _largeText;
  bool get boldText => _boldText;

  double get textScaleFactor => _largeText ? 1.35 : 1.0;

  Duration animationDuration(Duration normal) =>
      _reducedMotion ? Duration.zero : normal;

  Curve animationCurve(Curve normal) => _reducedMotion ? Curves.linear : normal;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed) return;
    _highContrast = SharedPrefs.getBool(_keyHighContrast) ?? false;
    _reducedMotion = SharedPrefs.getBool(_keyReducedMotion) ?? false;
    _largeText = SharedPrefs.getBool(_keyLargeText) ?? false;
    _boldText = SharedPrefs.getBool(_keyBoldText) ?? false;
    _safeNotify();
  }

  Future<void> setHighContrast(bool value) async {
    if (_disposed) return;
    _highContrast = value;
    await SharedPrefs.setBool(_keyHighContrast, value);
    _safeNotify();
  }

  Future<void> setReducedMotion(bool value) async {
    if (_disposed) return;
    _reducedMotion = value;
    await SharedPrefs.setBool(_keyReducedMotion, value);
    _safeNotify();
  }

  Future<void> setLargeText(bool value) async {
    if (_disposed) return;
    _largeText = value;
    await SharedPrefs.setBool(_keyLargeText, value);
    _safeNotify();
  }

  Future<void> setBoldText(bool value) async {
    if (_disposed) return;
    _boldText = value;
    await SharedPrefs.setBool(_keyBoldText, value);
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Builds a high-contrast theme from a seed theme.
  ThemeData applyToTheme(ThemeData base) {
    ThemeData result = base;

    if (_highContrast) {
      final cs = base.colorScheme;
      result = result.copyWith(
        colorScheme: cs.copyWith(
          // Boost contrast by darkening on-surface and brightening primary
          primary: _boostSaturation(cs.primary),
          onSurface:
              cs.brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
        dividerTheme: DividerThemeData(
          color: cs.brightness == Brightness.dark
              ? Colors.white54
              : Colors.black54,
          thickness: 1.5,
        ),
      );
    }

    if (_boldText) {
      result = result.copyWith(textTheme: _makeBold(result.textTheme));
    }

    return result;
  }

  TextTheme _makeBold(TextTheme t) {
    return t.copyWith(
      displayLarge: _bold(t.displayLarge),
      displayMedium: _bold(t.displayMedium),
      displaySmall: _bold(t.displaySmall),
      headlineLarge: _bold(t.headlineLarge),
      headlineMedium: _bold(t.headlineMedium),
      headlineSmall: _bold(t.headlineSmall),
      titleLarge: _bold(t.titleLarge),
      titleMedium: _bold(t.titleMedium),
      titleSmall: _bold(t.titleSmall),
      bodyLarge: _bold(t.bodyLarge),
      bodyMedium: _bold(t.bodyMedium),
      bodySmall: _bold(t.bodySmall),
      labelLarge: _bold(t.labelLarge),
      labelMedium: _bold(t.labelMedium),
      labelSmall: _bold(t.labelSmall),
    );
  }

  TextStyle? _bold(TextStyle? s) {
    if (s == null) return null;
    final current = s.fontWeight ?? FontWeight.normal;
    final index = FontWeight.values
        .indexOf(current)
        .clamp(0, FontWeight.values.length - 1);
    final newIndex = (index + 2).clamp(0, FontWeight.values.length - 1);
    return s.copyWith(fontWeight: FontWeight.values[newIndex]);
  }

  Color _boostSaturation(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withSaturation((hsl.saturation + 0.2).clamp(0.0, 1.0)).toColor();
  }
}
