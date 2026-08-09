import 'package:collection/collection.dart';
import 'package:mime/mime.dart';
import 'package:xml/xml.dart';

/// UPnP service type for the AVTransport control service.
const String avTransportServiceType =
    'urn:schemas-upnp-org:service:AVTransport:1';

/// UPnP service type for the RenderingControl (volume/mute) service.
const String renderingControlServiceType =
    'urn:schemas-upnp-org:service:RenderingControl:1';

/// A discovered UPnP/DLNA media renderer.
class CastDevice {
  /// Stable identity of the renderer (UDN when advertised, otherwise the
  /// description URL).
  final String id;

  /// Human readable name as advertised by the renderer.
  final String name;

  /// Host/IP of the renderer.
  final String address;

  /// Absolute URL of the `AVTransport:1` service control endpoint.
  final Uri controlUrl;

  /// Absolute URL of the `RenderingControl:1` service control endpoint, when
  /// the renderer advertises one.
  final Uri? renderingControlUrl;

  const CastDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.controlUrl,
    this.renderingControlUrl,
  });

  @override
  bool operator ==(Object other) => other is CastDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Extracts the `LOCATION` header value from a raw SSDP M-SEARCH response.
///
/// Header names are case-insensitive per RFC 2616, so the lookup is too.
/// Returns `null` when the response carries no usable location.
Uri? parseSsdpLocation(String response) {
  for (final rawLine in response.split(RegExp(r'\r?\n'))) {
    final separator = rawLine.indexOf(':');
    if (separator <= 0) continue;
    final name = rawLine.substring(0, separator).trim().toLowerCase();
    if (name != 'location') continue;
    final value = rawLine.substring(separator + 1).trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri;
  }
  return null;
}

/// Extracts the `USN` header from a raw SSDP response, used as a stable
/// device identity. Returns `null` when absent.
String? parseSsdpUsn(String response) {
  for (final rawLine in response.split(RegExp(r'\r?\n'))) {
    final separator = rawLine.indexOf(':');
    if (separator <= 0) continue;
    if (rawLine.substring(0, separator).trim().toLowerCase() != 'usn') continue;
    final value = rawLine.substring(separator + 1).trim();
    return value.isEmpty ? null : value;
  }
  return null;
}

/// Parses a UPnP device description document into a [CastDevice].
///
/// [location] is the URL the document was fetched from and is used both to
/// resolve relative `controlURL` values and as a fallback identity.
///
/// Returns `null` when the document is not a media renderer, is malformed, or
/// does not expose an `AVTransport:1` control endpoint — a renderer without
/// AVTransport cannot be told to play anything, so it must not be offered to
/// the user.
CastDevice? parseDeviceDescription(String xmlBody, Uri location) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(xmlBody);
  } on XmlException {
    return null;
  }

  final base = _resolveBaseUrl(document, location);

  Uri? controlUrl;
  Uri? renderingControlUrl;
  for (final service in document.findAllElements('service')) {
    final type = _childText(service, 'serviceType');
    final control = _childText(service, 'controlURL');
    if (type == null || control == null || control.isEmpty) continue;
    final resolved = _resolveUrl(base, control);
    if (resolved == null) continue;
    if (type == 'urn:schemas-upnp-org:service:AVTransport:1' ||
        type == 'urn:schemas-upnp-org:service:AVTransport:2' ||
        type == 'urn:schemas-upnp-org:service:AVTransport:3') {
      controlUrl ??= resolved;
    } else if (type == renderingControlServiceType) {
      renderingControlUrl ??= resolved;
    }
  }

  if (controlUrl == null) return null;

  final deviceElement = document.findAllElements('device').firstOrNull;
  final friendlyName = deviceElement != null
      ? _childText(deviceElement, 'friendlyName')
      : null;
  final udn = deviceElement != null ? _childText(deviceElement, 'UDN') : null;

  return CastDevice(
    id: (udn != null && udn.isNotEmpty) ? udn : location.toString(),
    name: (friendlyName != null && friendlyName.isNotEmpty)
        ? friendlyName
        : location.host,
    address: location.host,
    controlUrl: controlUrl,
    renderingControlUrl: renderingControlUrl,
  );
}

/// Resolves the document base: an explicit `<URLBase>` wins, otherwise the
/// description URL's origin is used.
Uri _resolveBaseUrl(XmlDocument document, Uri location) {
  final urlBase = document.findAllElements('URLBase').firstOrNull?.innerText;
  if (urlBase != null && urlBase.trim().isNotEmpty) {
    final parsed = Uri.tryParse(urlBase.trim());
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      return parsed;
    }
  }
  return location;
}

Uri? _resolveUrl(Uri base, String reference) {
  try {
    return base.resolve(reference.trim());
  } on FormatException {
    return null;
  }
}

String? _childText(XmlElement parent, String name) {
  final child =
      parent.findElements(name).firstOrNull ??
      parent.findAllElements(name).firstOrNull;
  final text = child?.innerText.trim();
  return (text == null || text.isEmpty) ? null : text;
}

/// Escapes a string for safe inclusion in XML character data.
///
/// DLNA payloads embed user-controlled file names inside SOAP bodies, and the
/// DIDL-Lite metadata is additionally embedded as *escaped* XML inside another
/// XML document, so correct escaping is required to avoid producing a
/// malformed request (or allowing tag injection) for titles containing
/// `&`, `<`, `>` or quotes.
String escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// Builds the DIDL-Lite metadata document describing the media item.
///
/// Renderers use the `protocolInfo` MIME type to decide which decoder to use,
/// so it is derived from the file name rather than hard-coded.
String buildDidlMetadata({
  required String title,
  required String streamUrl,
  String? mimeType,
}) {
  final resolvedMime = mimeType ?? lookupMimeType(title) ?? 'video/mp4';
  final upnpClass = resolvedMime.startsWith('audio/')
      ? 'object.item.audioItem.musicTrack'
      : 'object.item.videoItem';
  final protocolInfo = 'http-get:*:$resolvedMime:*';

  final escapedTitle = escapeXml(title);
  final escapedUrl = escapeXml(streamUrl);

  final rawDidl =
      '<DIDL-Lite '
      'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
      '<item id="0" parentID="-1" restricted="1">'
      '<dc:title>$escapedTitle</dc:title>'
      '<upnp:class>$upnpClass</upnp:class>'
      '<res protocolInfo="$protocolInfo">'
      '$escapedUrl'
      '</res>'
      '</item>'
      '</DIDL-Lite>';
  return escapeXml(rawDidl);
}

/// Wraps [innerXml] in a SOAP envelope for the given UPnP [action].
String buildSoapEnvelope({
  required String serviceType,
  required String action,
  String innerXml = '',
}) {
  return '<?xml version="1.0" encoding="utf-8"?>'
      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
      's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
      '<s:Body>'
      '<u:$action xmlns:u="$serviceType">'
      '<InstanceID>0</InstanceID>'
      '$innerXml'
      '</u:$action>'
      '</s:Body>'
      '</s:Envelope>';
}

/// Formats [duration] as the `HH:MM:SS` string required by
/// `AVTransport::Seek` with a `REL_TIME` unit.
String formatUpnpDuration(Duration duration) {
  final clamped = duration.isNegative ? Duration.zero : duration;
  final hours = clamped.inHours.toString().padLeft(2, '0');
  final minutes = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
