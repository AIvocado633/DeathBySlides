/// Pep Talk: the assists a player can switch on in Tweaks, one by one.
///
/// Each option is applied in exactly one place -- the player's health, the
/// enemy-shot base class, the player's grace window after a hit, the bullet
/// point's flight -- and never by a boss, so every feature built from here on
/// inherits them without doing anything. Nothing is held back while any of
/// them is on.
///
/// Like `Motion`, one value for the whole game: the game publishes the
/// player's choice as [current] whenever settings change. Tweaks cannot be
/// opened mid-fight, so a fight always runs on the choice it started with.
class PepTalk {
  const PepTalk({
    this.moreRoom = false,
    this.slowerShots = false,
    this.longerGrace = false,
    this.aimAssist = false,
  });

  /// What every fight is currently played with.
  static PepTalk current = const PepTalk();

  /// More room to shrink: the player takes more hits before shrinking away.
  /// Size still maps to speed the same way; each hit just costs less size.
  final bool moreRoom;

  /// Enemy shots fly slower.
  final bool slowerShots;

  /// The player stays untouchable for longer after a hit.
  final bool longerGrace;

  /// Bullet points bend gently towards the nearest target ahead of them.
  final bool aimAssist;

  static const int normalHits = 8;
  static const int roomyHits = 12;
  static const double slowShotScale = 0.7;
  static const double longGraceScale = 2;

  /// How many hits the player can take before the slide is lost.
  int get playerHits => moreRoom ? roomyHits : normalHits;

  /// What every enemy shot's speed is multiplied by.
  double get shotSpeedScale => slowerShots ? slowShotScale : 1;

  /// What the player's grace window after a hit is multiplied by.
  double get graceScale => longerGrace ? longGraceScale : 1;

  /// Whether any assist is on.
  bool get isOn => moreRoom || slowerShots || longerGrace || aimAssist;

  PepTalk copyWith({
    bool? moreRoom,
    bool? slowerShots,
    bool? longerGrace,
    bool? aimAssist,
  }) => PepTalk(
    moreRoom: moreRoom ?? this.moreRoom,
    slowerShots: slowerShots ?? this.slowerShots,
    longerGrace: longerGrace ?? this.longerGrace,
    aimAssist: aimAssist ?? this.aimAssist,
  );

  Map<String, Object?> toJson() => {
    'moreRoom': moreRoom,
    'slowerShots': slowerShots,
    'longerGrace': longerGrace,
    'aimAssist': aimAssist,
  };

  /// Reads what [toJson] wrote. Anything missing or unreadable is off: an
  /// assist is only ever on because the player switched it on.
  factory PepTalk.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return const PepTalk();
    }
    bool read(String key) => json[key] == true;
    return PepTalk(
      moreRoom: read('moreRoom'),
      slowerShots: read('slowerShots'),
      longerGrace: read('longerGrace'),
      aimAssist: read('aimAssist'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PepTalk &&
      other.moreRoom == moreRoom &&
      other.slowerShots == slowerShots &&
      other.longerGrace == longerGrace &&
      other.aimAssist == aimAssist;

  @override
  int get hashCode => Object.hash(moreRoom, slowerShots, longerGrace, aimAssist);
}
