import 'dart:convert';

/// Everything the game keeps between runs, as one versioned document.
///
/// One JSON document rather than a scatter of keys, so the save is read and
/// written whole, and [currentVersion] can turn a later change of shape into a
/// migration instead of a wipe.
class SaveData {
  const SaveData({
    this.progress = const Progress(),
    this.settings = const Settings(),
  });

  /// The shape [encode] writes and [SaveData.decode] reads.
  ///
  /// Bump it, with a migration from the old shape, when an existing field
  /// changes meaning. Adding a section needs no bump: a save written before the
  /// section existed loads it with its defaults.
  static const int currentVersion = 1;

  final Progress progress;
  final Settings settings;

  SaveData copyWith({Progress? progress, Settings? settings}) => SaveData(
    progress: progress ?? this.progress,
    settings: settings ?? this.settings,
  );

  String encode() => jsonEncode({
    'version': currentVersion,
    'progress': progress.toJson(),
    'settings': settings.toJson(),
  });

  /// Reads a document written by [encode].
  ///
  /// Throws a [FormatException] for anything else -- a save from a newer build
  /// of the game included -- and leaves it to the caller what to fall back to.
  factory SaveData.decode(String document) {
    final json = jsonDecode(document);
    if (json is! Map<String, Object?>) {
      throw const FormatException('A save is a JSON object');
    }
    final version = json['version'];
    if (version != currentVersion) {
      throw FormatException(
        'Save version $version; this build reads version $currentVersion',
      );
    }
    return SaveData(
      progress: Progress.fromJson(json['progress']),
      settings: Settings.fromJson(json['settings']),
    );
  }
}

/// How far through the deck the player has got.
class Progress {
  const Progress({this.beaten = const <int>{}});

  /// The numbers of the slides the player has won.
  final Set<int> beaten;

  bool hasBeaten(int slide) => beaten.contains(slide);

  Progress withBeaten(int slide) =>
      Progress(beaten: Set.unmodifiable({...beaten, slide}));

  Map<String, Object?> toJson() => {'beaten': beaten.toList()..sort()};

  /// Reads what [toJson] wrote. A missing section is a fresh start; anything
  /// else unexpected is a [FormatException].
  factory Progress.fromJson(Object? json) => switch (json) {
    null => const Progress(),
    {'beaten': final List<Object?> beaten}
        when beaten.every((slide) => slide is int) =>
      Progress(beaten: Set.unmodifiable(beaten.cast<int>())),
    _ => throw FormatException('Unreadable progress: ${jsonEncode(json)}'),
  };
}

/// What the player chose in Design Ideas.
class Settings {
  const Settings({
    this.swapSticks = false,
    this.deadzone = defaultDeadzone,
    this.stickSize = 1,
    this.reduceMotion,
  });

  /// The controller dead zone before anyone touches the slider, and the
  /// range the slider offers. Below 5% a worn stick drifts; above 40% a push
  /// has to travel so far that the player feels stuck.
  static const double defaultDeadzone = 0.2;
  static const double minDeadzone = 0.05;
  static const double maxDeadzone = 0.4;

  /// How big the on-screen thumb sticks are, as a fraction of their drawn
  /// size: smaller for small phones, bigger for big thumbs.
  static const double minStickSize = 0.8;
  static const double maxStickSize = 1.25;

  /// Move on the right thumb and aim on the left, for left-handed players.
  /// Touch only: keys and controller sticks stay where they are.
  final bool swapSticks;

  /// How far a controller stick has to travel before it counts as pushed.
  final double deadzone;

  final double stickSize;

  /// Whether decoration stays still. Null until the player chooses, which
  /// means following the device's own accessibility setting.
  final bool? reduceMotion;

  Settings copyWith({
    bool? swapSticks,
    double? deadzone,
    double? stickSize,
    bool? reduceMotion,
  }) => Settings(
    swapSticks: swapSticks ?? this.swapSticks,
    deadzone: deadzone ?? this.deadzone,
    stickSize: stickSize ?? this.stickSize,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );

  Map<String, Object?> toJson() => {
    'swapSticks': swapSticks,
    'deadzone': deadzone,
    'stickSize': stickSize,
    'reduceMotion': ?reduceMotion,
  };

  /// Reads what [toJson] wrote. A missing section, or a missing setting, is
  /// the default; a number outside its slider's range is pulled back into it.
  factory Settings.fromJson(Object? json) {
    if (json == null) {
      return const Settings();
    }
    if (json is! Map<String, Object?>) {
      throw FormatException('Unreadable settings: ${jsonEncode(json)}');
    }
    T? read<T>(String key) {
      final value = json[key];
      if (value != null && value is! T) {
        throw FormatException('Unreadable setting $key: ${jsonEncode(value)}');
      }
      return value as T?;
    }

    return Settings(
      swapSticks: read<bool>('swapSticks') ?? false,
      deadzone: (read<num>('deadzone') ?? defaultDeadzone).toDouble().clamp(
        minDeadzone,
        maxDeadzone,
      ),
      stickSize: (read<num>('stickSize') ?? 1).toDouble().clamp(
        minStickSize,
        maxStickSize,
      ),
      reduceMotion: read<bool>('reduceMotion'),
    );
  }
}
