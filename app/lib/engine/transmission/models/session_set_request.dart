class SessionSetRequest {
  final method = 'session-set';
  final SessionSetRequestArguments arguments;

  SessionSetRequest({required this.arguments});

  Map<String, dynamic> toJson() => {
        'method': method,
        'arguments': arguments.toJson(),
      };
}

class SessionSetRequestArguments {
  final String? downloadDir;
  final bool? downloadQueueEnabled;
  final int? downloadQueueSize;
  final int? peerPort;
  final bool? speedLimitDownEnabled;
  final bool? speedLimitUpEnabled;
  final int? speedLimitDown;
  final int? speedLimitUp;
  final double? seedRatioLimit;
  final bool? seedRatioLimited;

  // Privacy & security
  final String? encryption;
  final bool? blocklistEnabled;
  final String? blocklistUrl;
  final bool? dhtEnabled;
  final bool? pexEnabled;
  final bool? lpdEnabled;
  final bool? utpEnabled;

  // Alternative (turtle) speed limits & scheduler
  final bool? altSpeedEnabled;
  final int? altSpeedDown;
  final int? altSpeedUp;
  final bool? altSpeedTimeEnabled;
  final int? altSpeedTimeBegin;
  final int? altSpeedTimeEnd;
  final int? altSpeedTimeDay;

  // Idle seeding auto-stop
  final bool? idleSeedingLimitEnabled;
  final int? idleSeedingLimit;

  SessionSetRequestArguments({
    this.downloadDir,
    this.downloadQueueEnabled,
    this.downloadQueueSize,
    this.peerPort,
    this.speedLimitDownEnabled,
    this.speedLimitUpEnabled,
    this.speedLimitDown,
    this.speedLimitUp,
    this.seedRatioLimit,
    this.seedRatioLimited,
    this.encryption,
    this.blocklistEnabled,
    this.blocklistUrl,
    this.dhtEnabled,
    this.pexEnabled,
    this.lpdEnabled,
    this.utpEnabled,
    this.altSpeedEnabled,
    this.altSpeedDown,
    this.altSpeedUp,
    this.altSpeedTimeEnabled,
    this.altSpeedTimeBegin,
    this.altSpeedTimeEnd,
    this.altSpeedTimeDay,
    this.idleSeedingLimitEnabled,
    this.idleSeedingLimit,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (downloadDir != null) json['download-dir'] = downloadDir;
    if (downloadQueueEnabled != null) {
      json['download-queue-enabled'] = downloadQueueEnabled;
    }
    if (downloadQueueSize != null) {
      json['download-queue-size'] = downloadQueueSize;
    }
    if (peerPort != null) {
      json['peer-port'] = peerPort;
    }
    if (speedLimitDownEnabled != null) {
      json['speed-limit-down-enabled'] = speedLimitDownEnabled;
    }
    if (speedLimitUpEnabled != null) {
      json['speed-limit-up-enabled'] = speedLimitUpEnabled;
    }
    if (speedLimitDown != null) {
      json['speed-limit-down'] = speedLimitDown;
    }
    if (speedLimitUp != null) {
      json['speed-limit-up'] = speedLimitUp;
    }
    if (seedRatioLimit != null) {
      json['seedRatioLimit'] = seedRatioLimit;
    }
    if (seedRatioLimited != null) {
      json['seedRatioLimited'] = seedRatioLimited;
    }
    if (encryption != null) {
      json['encryption'] = encryption;
    }
    if (blocklistEnabled != null) {
      json['blocklist-enabled'] = blocklistEnabled;
    }
    if (blocklistUrl != null) {
      json['blocklist-url'] = blocklistUrl;
    }
    if (dhtEnabled != null) {
      json['dht-enabled'] = dhtEnabled;
    }
    if (pexEnabled != null) {
      json['pex-enabled'] = pexEnabled;
    }
    if (lpdEnabled != null) {
      json['lpd-enabled'] = lpdEnabled;
    }
    if (utpEnabled != null) {
      json['utp-enabled'] = utpEnabled;
    }
    if (altSpeedEnabled != null) {
      json['alt-speed-enabled'] = altSpeedEnabled;
    }
    if (altSpeedDown != null) {
      json['alt-speed-down'] = altSpeedDown;
    }
    if (altSpeedUp != null) {
      json['alt-speed-up'] = altSpeedUp;
    }
    if (altSpeedTimeEnabled != null) {
      json['alt-speed-time-enabled'] = altSpeedTimeEnabled;
    }
    if (altSpeedTimeBegin != null) {
      json['alt-speed-time-begin'] = altSpeedTimeBegin;
    }
    if (altSpeedTimeEnd != null) {
      json['alt-speed-time-end'] = altSpeedTimeEnd;
    }
    if (altSpeedTimeDay != null) {
      json['alt-speed-time-day'] = altSpeedTimeDay;
    }
    if (idleSeedingLimitEnabled != null) {
      json['idle-seeding-limit-enabled'] = idleSeedingLimitEnabled;
    }
    if (idleSeedingLimit != null) {
      json['idle-seeding-limit'] = idleSeedingLimit;
    }

    return json;
  }
}
