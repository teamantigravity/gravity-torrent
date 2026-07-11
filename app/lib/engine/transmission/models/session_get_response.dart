class SessionGetResponse {
  final SessionGetResponseArguments arguments;
  final String result;

  SessionGetResponse(this.arguments, this.result);

  SessionGetResponse.fromJson(Map<String, dynamic> json)
      : arguments = SessionGetResponseArguments.fromJson(json['arguments']),
        result = json['result'] as String;
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
      : downloadDir = json['download-dir'],
        downloadQueueEnabled = json['download-queue-enabled'],
        downloadQueueSize = json['download-queue-size'],
        peerPort = json['peer-port'],
        speedLimitDownEnabled = json['speed-limit-down-enabled'],
        speedLimitUpEnabled = json['speed-limit-up-enabled'],
        speedLimitDown = (json['speed-limit-down'] as num?)?.toInt(),
        speedLimitUp = (json['speed-limit-up'] as num?)?.toInt(),
        encryption = json['encryption'],
        blocklistEnabled = json['blocklist-enabled'],
        blocklistUrl = json['blocklist-url'],
        blocklistSize = (json['blocklist-size'] as num?)?.toInt(),
        dhtEnabled = json['dht-enabled'],
        pexEnabled = json['pex-enabled'],
        lpdEnabled = json['lpd-enabled'],
        utpEnabled = json['utp-enabled'],
        seedRatioLimit = (json['seedRatioLimit'] as num?)?.toDouble(),
        seedRatioLimited = json['seedRatioLimited'],
        idleSeedingLimitEnabled = json['idle-seeding-limit-enabled'],
        idleSeedingLimit = (json['idle-seeding-limit'] as num?)?.toInt(),
        altSpeedEnabled = json['alt-speed-enabled'],
        altSpeedDown = (json['alt-speed-down'] as num?)?.toInt(),
        altSpeedUp = (json['alt-speed-up'] as num?)?.toInt(),
        altSpeedTimeEnabled = json['alt-speed-time-enabled'],
        altSpeedTimeBegin = (json['alt-speed-time-begin'] as num?)?.toInt(),
        altSpeedTimeEnd = (json['alt-speed-time-end'] as num?)?.toInt(),
        altSpeedTimeDay = (json['alt-speed-time-day'] as num?)?.toInt();
}
