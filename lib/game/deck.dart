import 'levels.dart';
import 'save/save_data.dart';

/// Developer switch that opens every built slide, so a boss can be worked on
/// without replaying the deck first: `--dart-define=UNLOCK_ALL=true`.
///
/// Read once, here, as the game's default; tests pass their own value instead.
const bool kUnlockAll = bool.fromEnvironment('UNLOCK_ALL');

/// Where a slide stands, in the light table's own vocabulary.
enum SlideState {
  /// Won at least once. Still playable.
  beaten,

  /// Playable, and not won yet.
  unlocked,

  /// Built, but the slide before it has not been won yet.
  locked,

  /// No fight exists for it in this build, so it is shown as a hidden slide.
  notBuilt,
}

/// The run through the deck: which slides the player may open, given what
/// they have won so far.
///
/// A plain value, worked out from [levels] and [progress] whenever it is
/// asked for, so it never goes stale.
class Deck {
  const Deck({
    required this.progress,
    this.levels = kLevels,
    this.unlockAll = false,
  });

  final List<LevelDefinition> levels;
  final Progress progress;

  /// Opens every built slide, whatever has been won. See [kUnlockAll].
  final bool unlockAll;

  SlideState stateOf(int slide) {
    final level = _level(slide);
    if (level == null || !level.isBuilt) {
      return SlideState.notBuilt;
    }
    if (progress.hasBeaten(slide)) {
      return SlideState.beaten;
    }
    return unlockAll ||
            slide == levels.first.number ||
            progress.hasBeaten(slide - 1)
        ? SlideState.unlocked
        : SlideState.locked;
  }

  /// Whether [slide] can be opened: built, and either the first slide or one
  /// that follows a beaten slide.
  bool isPlayable(int slide) => switch (stateOf(slide)) {
    SlideState.beaten || SlideState.unlocked => true,
    SlideState.locked || SlideState.notBuilt => false,
  };

  /// The slide Next Slide goes to once [slide] is won, or null when the next
  /// one has not been built yet (or there is none).
  int? nextAfter(int slide) {
    final next = _level(slide + 1);
    return next != null && next.isBuilt ? next.number : null;
  }

  /// Where *From Current Slide* starts: the first built slide not won yet, or
  /// null once every built slide has been.
  int? get resumeSlide {
    for (final level in levels) {
      if (level.isBuilt && !progress.hasBeaten(level.number)) {
        return level.number;
      }
    }
    return null;
  }

  /// Whether anything has been won yet.
  bool get hasProgress =>
      levels.any((level) => progress.hasBeaten(level.number));

  /// The slide the status bar calls current: the one to resume from, or the
  /// last built slide once there is nothing left to resume.
  int get currentSlide =>
      resumeSlide ?? levels.lastWhere((level) => level.isBuilt).number;

  /// Whether [slide] is the deck's last: winning it ends the slide show.
  bool endsTheShow(int slide) => slide == levels.last.number;

  /// Whether every slide has been won: the deck has been presented.
  bool get isFinished => featuresLeft == 0;

  /// How many features still stand between the player and the end of the
  /// deck, built or not.
  int get featuresLeft =>
      levels.where((level) => !progress.hasBeaten(level.number)).length;

  LevelDefinition? _level(int slide) {
    for (final level in levels) {
      if (level.number == slide) {
        return level;
      }
    }
    return null;
  }
}
