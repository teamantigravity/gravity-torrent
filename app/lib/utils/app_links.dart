import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:share_plus/share_plus.dart';

enum Environment { production, preview, development }

final appUri = const String.fromEnvironment('APP_URL').isNotEmpty
    ? const String.fromEnvironment('APP_URL')
    : 'http://localhost:3000/';

String createAppLink(String link) {
  final fragmentUri = Uri(queryParameters: {'magnet': link}).toString();
  final Uri uri = Uri(fragment: fragmentUri);
  final String uriString = uri.toString();
  // uri.toString() is '#?magnet=...' when the fragment is non-empty.
  final payload = uriString.startsWith('#?')
      ? uriString.substring(2)
      : (uriString.startsWith('#') ? uriString.substring(1) : fragmentUri);
  final String fragmentString = encodeToBase64(payload);
  final appLink = Uri.encodeFull('$appUri#$fragmentString');

  return appLink;
}

/// get torrent link from an link which contains a fragment (#)
/// It does not matter if it's a https:// or gravitytorrent:// link
String? getTorrentLink(String appLink) {
  final hashIndex = appLink.indexOf('#');
  if (hashIndex == -1) {
    return null;
  }

  try {
    final rawFragment = appLink.substring(hashIndex + 1);
    final String fragment = decodeBase64(Uri.decodeComponent(rawFragment));
    final Uri uri = Uri(query: fragment);
    return uri.queryParameters['magnet'];
  } catch (_) {
    return null;
  }
}

bool isAppLink(String appLink) {
  try {
    final uri = Uri.parse(appLink);
    final base = Uri.parse(appUri);
    return uri.scheme == base.scheme &&
        uri.host == base.host &&
        uri.port == base.port &&
        uri.path == base.path;
  } catch (_) {
    return false;
  }
}

Future<void> shareLink(BuildContext context, String magnetLink) async {
  await shareLinks(context, [magnetLink]);
}

Future<void> shareLinks(BuildContext context, List<String> magnetLinks) async {
  if (magnetLinks.isEmpty) return;
  final links = magnetLinks.map(createAppLink).join('\n');

  if (isMobile()) {
    await SharePlus.instance.share(ShareParams(text: links));
  } else {
    await Clipboard.setData(ClipboardData(text: links));
    if (!context.mounted) return;
    final localizations = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(localizations.linksCopied),
        backgroundColor: Colors.lightGreen,
      ),
    );
  }
}

String encodeToBase64(String input) {
  return base64Encode(utf8.encode(input));
}

String decodeBase64(String input) {
  return utf8.decode(base64Decode(input));
}
