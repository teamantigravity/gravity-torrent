T? _cast<T>(dynamic value) => value is T ? value : null;

class SessionGetResponse {
  final SessionGetResponseArguments arguments;
  final String result;

  SessionGetResponse(this.arguments, this.result);

  SessionGetResponse.fromJson(Map<String, dynamic> json)
      : arguments = SessionGetResponseArguments.fromJson(
            json['arguments'] is Map
                ? json['arguments'] as Map<String, dynamic>
                : const {},
          ),
        result = json['result'] as String? ?? '';
}

class SessionGetResponseArguments {
  final String? downloadDir;
  final bool? downloadQueueEnabled;
  final int? downloadQueueSize;
  final int? peerPort;
  final bool? speedLimitDownEnabled;
  final bool? speedLimitUpEnabled;
  final int? speedLimitDown;
  final int? speedLimitUp;

  // Privacy & security
  final String? encryption;
  final bool? blocklistEnabled;
  final String? blocklistUrl;
  final int? blocklistSize;
  final bool? dhtEnabled;
  final bool? pexEnabled;
  final bool? lpdEnabled;
  final bool? utpEnabled;

  // Seeding limits
  final double? seedRatioLimit;
  final bool? seedRatioLimited;
  final bool? idleSeedingLimitEnabled;
  final int? idleSeedingLimit;

  // Alternative (turtle) speed limits & scheduler
  final bool? altSpeedEnabled;
  final int? altSpeedDown;
  final int? altSpeedUp;
  final bool? altSpeedTimeEnabled;
  final int? altSpeedTimeBegin;
  final int? altSpeedTimeEnd;
  final int? altSpeedTimeDay;

  SessionGetResponseArguments.fromJson(Map<String, dynamic> json)
      : downloadDir = _cast<String>(json['download-dir']),
        downloadQueueEnabled = _cast<bool>(json['download-queue-enabled']),
        downloadQueueSize = _cast<num>(json['download-queue-size'])?.toInt(),
        peerPort = _cast<num>(json['peer-port'])?.toInt(),
        speedLimitDownEnabled = _cast<bool>(json['speed-limit-down-enabled']),
        speedLimitUpEnabled = _cast<bool>(json['speed-limit-up-enabled']),
        speedLimitDown = _cast<num>(json['speed-limit-down'])?.toInt(),
        speedLimitUp = _cast<num>(json['speed-limit-up'])?.toInt(),
        encryption = _cast<String>(json['encryption']),
        blocklistEnabled = _cast<bool>(json['blocklist-enabled']),
        blocklistUrl = _cast<String>(json['blocklist-url']),
        blocklistSize = _cast<num>(json['blocklist-size'])?.toInt(),
        dhtEnabled = _cast<bool>(json['dht-enabled']),
        pexEnabled = _cast<bool>(json['pex-enabled']),
        lpdEnabled = _cast<bool>(json['lpd-enabled']),
        utpEnabled = _cast<bool>(json['utp-enabled']),
        seedRatioLimit = _cast<num>(json['seedRatioLimit'])?.toDouble(),
        seedRatioLimited = _cast<bool>(json['seedRatioLimited']),
        idleSeedingLimitEnabled = _cast<bool>(json['idle-seeding-limit-enabled']),
        idleSeedingLimit = _cast<num>(json['idle-seeding-limit'])?.toInt(),
        altSpeedEnabled = _cast<bool>(json['alt-speed-enabled']),
        altSpeedDown = _cast<num>(json['alt-speed-down'])?.toInt(),
        altSpeedUp = _cast<num>(json['alt-speed-up'])?.toInt(),
        altSpeedTimeEnabled = _cast<bool>(json['alt-speed-time-enabled']),
        altSpeedTimeBegin = _cast<num>(json['alt-speed-time-begin'])?.toInt(),
        altSpeedTimeEnd = _cast<num>(json['alt-speed-time-end'])?.toInt(),
        altSpeedTimeDay = _cast<num>(json['alt-speed-time-day'])?.toInt();
}
