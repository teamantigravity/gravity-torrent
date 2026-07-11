enum SessionField {
  downloadDir,
  downloadQueueEnabled,
  downloadQueueSize,
  peerPort,
  speedLimitDownEnabled,
  speedLimitUpEnabled,
  speedLimitDown,
  speedLimitUp,
  encryption,
  blocklistEnabled,
  blocklistUrl,
  blocklistSize,
  dhtEnabled,
  pexEnabled,
  lpdEnabled,
  utpEnabled,
  seedRatioLimit,
  seedRatioLimited,
  altSpeedEnabled,
  altSpeedDown,
  altSpeedUp,
  altSpeedTimeEnabled,
  altSpeedTimeBegin,
  altSpeedTimeEnd,
  altSpeedTimeDay,
  idleSeedingLimitEnabled,
  idleSeedingLimit,
}

class SessionGetRequest {
  final method = 'session-get';
  final SessionGetRequestArguments arguments;

  SessionGetRequest({required this.arguments});

  Map<String, dynamic> toJson() =>
      {'method': method, 'arguments': arguments.toJson()};
}

class SessionGetRequestArguments {
  final List<SessionField> fields;

  SessionGetRequestArguments({required this.fields});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'fields': fields.map((field) {
        return switch (field) {
          SessionField.downloadDir => 'download-dir',
          SessionField.downloadQueueEnabled => 'download-queue-enabled',
          SessionField.downloadQueueSize => 'download-queue-size',
          SessionField.peerPort => 'peer-port',
          SessionField.speedLimitDownEnabled => 'speed-limit-down-enabled',
          SessionField.speedLimitUpEnabled => 'speed-limit-up-enabled',
          SessionField.speedLimitDown => 'speed-limit-down',
          SessionField.speedLimitUp => 'speed-limit-up',
          SessionField.encryption => 'encryption',
          SessionField.blocklistEnabled => 'blocklist-enabled',
          SessionField.blocklistUrl => 'blocklist-url',
          SessionField.blocklistSize => 'blocklist-size',
          SessionField.dhtEnabled => 'dht-enabled',
          SessionField.pexEnabled => 'pex-enabled',
          SessionField.lpdEnabled => 'lpd-enabled',
          SessionField.utpEnabled => 'utp-enabled',
          SessionField.seedRatioLimit => 'seedRatioLimit',
          SessionField.seedRatioLimited => 'seedRatioLimited',
          SessionField.altSpeedEnabled => 'alt-speed-enabled',
          SessionField.altSpeedDown => 'alt-speed-down',
          SessionField.altSpeedUp => 'alt-speed-up',
          SessionField.altSpeedTimeEnabled => 'alt-speed-time-enabled',
          SessionField.altSpeedTimeBegin => 'alt-speed-time-begin',
          SessionField.altSpeedTimeEnd => 'alt-speed-time-end',
          SessionField.altSpeedTimeDay => 'alt-speed-time-day',
          SessionField.idleSeedingLimitEnabled => 'idle-seeding-limit-enabled',
          SessionField.idleSeedingLimit => 'idle-seeding-limit'
        };
      }).toList()
    };

    return json;
  }
}
