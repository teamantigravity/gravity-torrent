import 'package:gravity_torrent/navigation/navigation.dart';

/// Adaptive shell wrapper that switches between a bottom navigation bar and a
/// navigation rail depending on the window size.
///
/// The actual rendering is delegated to [Navigation], which lives in
/// [lib/navigation] because it owns the app's route destinations.
class AdaptiveNavigation extends Navigation {
  const AdaptiveNavigation({super.key, required super.child});
}
