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
  final EncryptionMode? encryption;
  final bool? blocklistEnabled;
  final String? blocklistUrl;
  final int? blocklistSize;
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

  SessionBase(
      {this.downloadDir,
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
      this.idleSeedingLimit});
}

// BitTorrent session abstraction
abstract class Session extends SessionBase {
  Session(
      {super.downloadDir,
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
      super.idleSeedingLimit});

  // Update a session
  Future<void> update(SessionBase session);
}
