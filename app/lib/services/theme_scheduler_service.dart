import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:gravity_torrent/models/app.dart';

/// Service that derives the app's active [ThemeMode] and AMOLED preference,
/// and applies an AMOLED override to a dark theme when requested.
///
/// Currently mirrors the values stored in [AppModel] so existing UI keeps
/// working. Time-of-day scheduling can be layered on top later by extending
/// [materialThemeMode] with scheduled start/end times.
class ThemeSchedulerService extends ChangeNotifier {
  AppModel? _app;
  bool _disposed = false;

  void _safeNotify() {
    if (_disposed) return;
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) {
        if (!_disposed) super.notifyListeners();
      });
    } else {
      super.notifyListeners();
    }
  }

  /// Attaches this service to an [AppModel] instance so theme changes are
  /// propagated to listeners.
  void attachAppModel(AppModel app) {
    if (_app == app) return;
    _app?.removeListener(_onAppChanged);
    _app = app;
    _app?.addListener(_onAppChanged);
    _onAppChanged();
  }

  void _onAppChanged() => _safeNotify();

  /// The [ThemeMode] to pass to [MaterialApp.themeMode].
  ThemeMode get materialThemeMode => _app?.theme ?? ThemeMode.system;

  /// Whether the user has enabled AMOLED/true-black mode.
  bool get isAmoled => _app?.amoledBlack ?? false;

  /// Applies an AMOLED override to [theme] when [isAmoled] is true and the
  /// theme is dark. Otherwise returns [theme] unchanged.
  ThemeData applyAmoled(ThemeData theme) {
    if (!isAmoled || theme.brightness != Brightness.dark) return theme;

    final colorScheme = theme.colorScheme.copyWith(surface: Colors.black);
    return theme.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.black,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _app?.removeListener(_onAppChanged);
    _app = null;
    super.dispose();
  }
}
