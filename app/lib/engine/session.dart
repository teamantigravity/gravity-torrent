/// Protocol encryption preference for peer connections.
///
/// Mirrors libtransmission's `encryption` RPC values.
enum EncryptionMode {
  /// Allow unencrypted connections (`tolerated`).
  tolerated,

  /// Prefer encrypted connections but fall back (`preferred`).
  preferred,

  /// Only allow encrypted connections (`required`).
  required;

  /// The Transmission RPC string value for this mode.
  String get rpcValue => switch (this) {
    EncryptionMode.tolerated => 'tolerated',
    EncryptionMode.preferred => 'preferred',
    EncryptionMode.required => 'required',
  };

  /// Parse a Transmission RPC string value into an [EncryptionMode].
  static EncryptionMode fromRpcValue(String? value) => switch (value) {
    'tolerated' => EncryptionMode.tolerated,
    'required' => EncryptionMode.required,
    _ => EncryptionMode.preferred,
  };
}

class SessionBase {
  String? downloadDir;
  bool? downloadQueueEnabled;
  int? downloadQueueSize;
  int? peerPort;
  bool? speedLimitDownEnabled;
  bool? speedLimitUpEnabled;
  int? speedLimitDown;
  int? speedLimitUp;
  double? seedRatioLimit;
  bool? seedRatioLimited;

  // Privacy & security
  EncryptionMode? encryption;
  bool? blocklistEnabled;
  String? blocklistUrl;
  int? blocklistSize;
  bool? dhtEnabled;
  bool? pexEnabled;
  bool? lpdEnabled;
  bool? utpEnabled;

  // Alternative (turtle) speed limits & scheduler
  bool? altSpeedEnabled;
  int? altSpeedDown;
  int? altSpeedUp;
  bool? altSpeedTimeEnabled;
  int? altSpeedTimeBegin;
  int? altSpeedTimeEnd;
  int? altSpeedTimeDay;

  // Idle seeding auto-stop
  bool? idleSeedingLimitEnabled;
  int? idleSeedingLimit;

  SessionBase({
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
    this.blocklistSize,
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
}

// BitTorrent session abstraction
abstract class Session extends SessionBase {
  Session({
    super.downloadDir,
    super.downloadQueueEnabled,
    super.downloadQueueSize,
    super.peerPort,
    super.speedLimitDownEnabled,
    super.speedLimitUpEnabled,
    super.speedLimitDown,
    super.speedLimitUp,
    super.seedRatioLimit,
    super.seedRatioLimited,
    super.encryption,
    super.blocklistEnabled,
    super.blocklistUrl,
    super.blocklistSize,
    super.dhtEnabled,
    super.pexEnabled,
    super.lpdEnabled,
    super.utpEnabled,
    super.altSpeedEnabled,
    super.altSpeedDown,
    super.altSpeedUp,
    super.altSpeedTimeEnabled,
    super.altSpeedTimeBegin,
    super.altSpeedTimeEnd,
    super.altSpeedTimeDay,
    super.idleSeedingLimitEnabled,
    super.idleSeedingLimit,
  });

  // Update a session
  Future<void> update(SessionBase session);
}
