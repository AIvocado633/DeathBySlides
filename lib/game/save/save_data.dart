import 'dart:convert';

import '../combat/pep_talk.dart';

export '../combat/pep_talk.dart' show PepTalk;

/// Everything the game keeps between runs, as one versioned document.
///
/// One JSON document rather than a scatter of keys, so the save is read and
/// written whole, and [currentVersion] can turn a later change of shape into a
/// migration instead of a wipe.
class SaveData {
  const SaveData({
    this.progress = const Progress(),
    this.settings = const Settings(),
    this.introSeen = false,
  });

  /// The shape [encode] writes and [SaveData.decode] reads.
  ///
  /// Bump it, with a migration from the old shape, when an existing field
  /// changes meaning. Adding a section needs no bump: a save written before the
  /// section existed loads it with its defaults.
  static const int currentVersion = 1;

  final Progress progress;
  final Settings settings;

  /// Whether the intro has played through or been skipped, so it plays once.
  final bool introSeen;

  SaveData copyWith({
    Progress? progress,
    Settings? settings,
    bool? introSeen,
  }) => SaveData(
    progress: progress ?? this.progress,
    settings: settings ?? this.settings,
    introSeen: introSeen ?? this.introSeen,
  );

  String encode() => jsonEncode({
    'version': currentVersion,
    'progress': progress.toJson(),
    'settings': settings.toJson(),
    if (introSeen) 'introSeen': true,
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
      introSeen: json['introSeen'] == true,
    );
  }
}

/// How far through the deck the player has got.
class Progress {
  const Progress({
    this.beaten = const <int>{},
    this.bestTimes = const <int, SlideTime>{},
  });

  /// The numbers of the slides the player has won.
  final Set<int> beaten;

  /// The fastest win of each slide that has one, as Rehearse Timings keeps
  /// a time for every slide.
  final Map<int, SlideTime> bestTimes;

  bool hasBeaten(int slide) => beaten.contains(slide);

  SlideTime? bestTimeOf(int slide) => bestTimes[slide];

  Progress withBeaten(int slide) => Progress(
    beaten: Set.unmodifiable({...beaten, slide}),
    bestTimes: bestTimes,
  );

  /// Keeps [time] as [slide]'s best, unless the best is already faster.
  Progress withTime(int slide, SlideTime time) {
    final best = bestTimes[slide];
    if (best != null && !time.beats(best)) {
      return this;
    }
    return Progress(
      beaten: beaten,
      bestTimes: Map.unmodifiable({...bestTimes, slide: time}),
    );
  }

  Map<String, Object?> toJson() => {
    'beaten': beaten.toList()..sort(),
    if (bestTimes.isNotEmpty)
      'bestTimes': {
        for (final slide in bestTimes.keys.toList()..sort())
          '$slide': bestTimes[slide]!.toJson(),
      },
  };

  /// Reads what [toJson] wrote. A missing section is a fresh start; anything
  /// else unexpected is a [FormatException] -- except a time that cannot be
  /// read, which is dropped: losing one time is better than losing the save.
  factory Progress.fromJson(Object? json) => switch (json) {
    null => const Progress(),
    {'beaten': final List<Object?> beaten} && final Map<Object?, Object?> all
        when beaten.every((slide) => slide is int) =>
      Progress(
        beaten: Set.unmodifiable(beaten.cast<int>()),
        bestTimes: Map.unmodifiable(_readTimes(all['bestTimes'])),
      ),
    _ => throw FormatException('Unreadable progress: ${jsonEncode(json)}'),
  };

  static Map<int, SlideTime> _readTimes(Object? json) {
    if (json is! Map<String, Object?>) {
      return const {};
    }
    return {
      for (final MapEntry(:key, :value) in json.entries)
        if ((int.tryParse(key), SlideTime.tryFromJson(value))
            case (final int slide, final SlideTime time))
          slide: time,
    };
  }
}

/// How long a slide took to win, as Rehearse Timings would record it.
class SlideTime {
  const SlideTime(this.seconds, {this.pepTalk = false});

  final double seconds;

  /// Whether any Pep Talk assist was on. Such a time counts like any other,
  /// and is marked as such rather than hidden.
  final bool pepTalk;

  /// Whether this run was faster than [other].
  bool beats(SlideTime other) => seconds < other.seconds;

  /// The time as a rehearsal shows it: `00:42`, whole seconds.
  String get clock => formatClock(seconds);

  /// [clock], marked when Pep Talk was on: `00:42 (Pep Talk)`.
  String get label => pepTalk ? '$clock (Pep Talk)' : clock;

  /// `mm:ss`, whole seconds, rounded down.
  static String formatClock(double seconds) {
    final whole = seconds.floor();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(whole ~/ 60)}:${two(whole % 60)}';
  }

  Map<String, Object?> toJson() => {'seconds': seconds, 'pepTalk': pepTalk};

  /// Reads what [toJson] wrote, or null for anything else.
  static SlideTime? tryFromJson(Object? json) => switch (json) {
    {'seconds': final num seconds} && final Map<Object?, Object?> all
        when seconds.isFinite && seconds > 0 =>
      SlideTime(seconds.toDouble(), pepTalk: all['pepTalk'] == true),
    _ => null,
  };
}

/// What the player chose in Tweaks.
class Settings {
  const Settings({
    this.swapSticks = false,
    this.deadzone = defaultDeadzone,
    this.stickSize = 1,
    this.reduceMotion,
    this.musicVolume = defaultMusicVolume,
    this.effectsVolume = defaultEffectsVolume,
    this.pepTalk = const PepTalk(),
  });

  /// Where the Sound sliders start. Music sits under the effects, so a shot
  /// is always heard over the hold music.
  static const double defaultMusicVolume = 0.5;
  static const double defaultEffectsVolume = 0.8;

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

  /// Music and effects volume, 0–1. Zero is off: nothing of that side is
  /// loaded or played.
  final double musicVolume;
  final double effectsVolume;

  /// The assists switched on. All off until the player picks some.
  final PepTalk pepTalk;

  Settings copyWith({
    bool? swapSticks,
    double? deadzone,
    double? stickSize,
    bool? reduceMotion,
    double? musicVolume,
    double? effectsVolume,
    PepTalk? pepTalk,
  }) => Settings(
    swapSticks: swapSticks ?? this.swapSticks,
    deadzone: deadzone ?? this.deadzone,
    stickSize: stickSize ?? this.stickSize,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    musicVolume: musicVolume ?? this.musicVolume,
    effectsVolume: effectsVolume ?? this.effectsVolume,
    pepTalk: pepTalk ?? this.pepTalk,
  );

  Map<String, Object?> toJson() => {
    'swapSticks': swapSticks,
    'deadzone': deadzone,
    'stickSize': stickSize,
    'reduceMotion': ?reduceMotion,
    'musicVolume': musicVolume,
    'effectsVolume': effectsVolume,
    'pepTalk': pepTalk.toJson(),
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
      musicVolume: (read<num>('musicVolume') ?? defaultMusicVolume)
          .toDouble()
          .clamp(0, 1),
      effectsVolume: (read<num>('effectsVolume') ?? defaultEffectsVolume)
          .toDouble()
          .clamp(0, 1),
      pepTalk: PepTalk.fromJson(json['pepTalk']),
    );
  }
}
