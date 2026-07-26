import 'dart:convert';
import 'dart:math';

/// Generates a URL-safe, cryptographically secure random token.
///
/// [length] is the number of raw bytes drawn from [Random.secure] before
/// base64-url encoding, so the returned string is longer than [length].
String generateSecureRandomToken({int length = 32}) {
  final random = Random.secure();
  final bytes = List<int>.generate(length, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Returns true when the first path segment of [requestPath] is exactly
/// [token].
///
/// Used to gate a locally bound HTTP server with a capability token. The match
/// is on the whole first segment so a longer guess such as `/tokenX` cannot
/// pass a prefix check, and an empty token never authorises anything.
bool pathCarriesToken(String requestPath, String token) {
  if (token.isEmpty) return false;
  var path = requestPath;
  while (path.startsWith('/')) {
    path = path.substring(1);
  }
  final slash = path.indexOf('/');
  final segment = slash == -1 ? path : path.substring(0, slash);
  return segment == token;
}
