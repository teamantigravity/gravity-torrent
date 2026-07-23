import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:http/http.dart' as http;
import 'package:store_checker/store_checker.dart';
import 'package:windows_store/windows_store.dart';

const String _githubReleasesUrl =
    'https://api.github.com/repos/teamantigravity/gravity-torrent/releases?per_page=30';

// Rolling "latest successful build" release published by CI. Its tag is not a
// semantic version and must never be treated as an upgrade target, otherwise
// version parsing fails and update checks silently do nothing.
const String _rollingReleaseTag = 'latest-successful-build';

// Returns the latest update version, or null
Future<String?> checkForUpdate(String version) async {
  if (await isDistributedFromAppStore()) return null;

  try {
    final response = await http.get(Uri.parse(_githubReleasesUrl));

    if (response.statusCode != 200) return null;

    final dynamic data = jsonDecode(response.body);
    if (data is! List) return null;

    return latestUpgradeVersion(data, Version.parse(version));
  } catch (e) {
    debugPrint('Error checking for new release: $e');
  }

  return null;
}

// Selects the newest published semver release that is strictly greater than
// [currentVersion] from a GitHub releases list payload. Drafts, pre-releases
// and the rolling CI build tag are ignored. Returns null when there is no
// newer version. Exposed for testing.
@visibleForTesting
String? latestUpgradeVersion(List<dynamic> releases, Version currentVersion) {
  Version? latestVersion;

  for (final release in releases) {
    if (release is! Map) continue;
    // Skip drafts, pre-releases and the rolling CI build.
    if (release['draft'] == true || release['prerelease'] == true) continue;
    final tagName = release['tag_name'];
    if (tagName is! String || tagName == _rollingReleaseTag) continue;

    final candidate = _tryParseVersion(tagName);
    if (candidate == null) continue;

    if (latestVersion == null || candidate > latestVersion) {
      latestVersion = candidate;
    }
  }

  if (latestVersion != null && latestVersion > currentVersion) {
    return latestVersion.toString();
  }
  return null;
}

// Parse a release tag into a [Version], tolerating an optional leading 'v'.
// Returns null for non-semver tags instead of throwing.
Version? _tryParseVersion(String tag) {
  final normalized = tag.startsWith('v') ? tag.substring(1) : tag;
  try {
    return Version.parse(normalized);
  } catch (e, s) {
    if (kDebugMode) {
      debugPrint('Failed to parse version tag $tag: $e\n$s');
    }
    return null;
  }
}

// Check if app is in release mode, and try to find out
// if it's distributed through an app store
Future<bool> isDistributedFromAppStore() async {
  if (kDebugMode) return false;

  if (isDesktop()) {
    if (Platform.isWindows) {
      // Check if app is installed through Microsoft Store
      try {
        final windowsStore = WindowsStoreApi();
        final license = await windowsStore.getAppLicenseAsync();
        return license.isActive;
      } catch (e) {
        if (kDebugMode) debugPrint('WindowsStore license check failed: $e');
        return false;
      }
    }

    return isFlatpak();
  }

  try {
    Source installationSource = await StoreChecker.getSource;
    return switch (installationSource) {
      Source.IS_INSTALLED_FROM_LOCAL_SOURCE => false,
      Source.UNKNOWN => false,
      _ => true,
    };
  } catch (e) {
    if (kDebugMode) debugPrint('StoreChecker failed: $e');
    return false;
  }
}
