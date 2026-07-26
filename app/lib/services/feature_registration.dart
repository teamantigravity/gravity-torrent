import 'package:provider/provider.dart';
import 'package:gravity_torrent/services/in_app_review_service.dart';
import 'package:gravity_torrent/services/notification_channel_service.dart';
import 'package:gravity_torrent/services/player_enhancements_service.dart';
import 'package:gravity_torrent/services/auto_extract_service.dart';
import 'package:gravity_torrent/services/bandwidth_heatmap_service.dart';

import 'package:provider/single_child_widget.dart';

/// Returns all the [ChangeNotifierProvider]s for the new features.
///
/// Add these to your root [MultiProvider]. Note that [AccessibilityService]
/// and [ThemeSchedulerService] are wired in [main.dart] so they can be loaded
/// and attached to [AppModel] before the first frame.
List<SingleChildWidget> featureProviders() {
  return [
    ChangeNotifierProvider<PlayerEnhancementsService>(
      create: (_) => PlayerEnhancementsService(),
    ),
    ChangeNotifierProvider<AutoExtractService>.value(
      value: AutoExtractService.instance,
    ),
    ChangeNotifierProvider<BandwidthHeatmapService>(
      create: (_) => BandwidthHeatmapService(),
    ),
  ];
}

/// Call once during app initialization (in main.dart).
Future<void> initializeFeatures() async {
  // Feature 1: Record launch for in-app review
  await InAppReviewService.recordLaunch();

  // Feature 14: Initialize notification channels.
  // NOTE: Existing initializeNotifications() in main.dart already initializes
  // the shared FlutterLocalNotificationsPlugin. This call only creates the new
  // Android channels without overriding the existing plugin callbacks.
  await NotificationChannelService.initialize();

  // Onboarding redirect is handled by the router.
}
