import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../audio/game_audio.dart';
import 'projectiles.dart';

/// How the player leaves a lost slide: the exit animation it plays.
enum PlayerExit {
  /// Spins away to nothing.
  spinOut,

  /// Flies up and off the slide.
  flyOut,
}

/// Where a body of `bodySize` that means to be at `intended` is actually put:
/// how a feature constrains the player's movement.
typedef PositionFilter = Vector2 Function(Vector2 intended, Vector2 bodySize);

/// Builds the feature a slide is fought against, from what the arena hands it.
typedef BossBuilder = Boss Function(BossContext context);

/// What the arena hands a feature when a slide starts.
///
/// Bundled into one object so that a boss needing something new from the
/// arena adds a field here, rather than a parameter to every boss there is.
class BossContext {
  const BossContext({
    required this.arenaSize,
    required this.aimAt,
    required this.onDefeated,
    this.setPlayerShotRules = _keepPlayerShots,
    this.setPlayerPositionFilter = _keepPlayerMoving,
    this.strikePlayer = _missPlayer,
  });

  /// The size of the floor the fight happens on. Bosses work in arena-local
  /// coordinates, so this is where they place themselves.
  final Vector2 arenaSize;

  /// Where to throw things: the player's arena-local position.
  final Vector2 Function() aimAt;

  /// To be called once the feature is gone and any death animation has played.
  final void Function() onDefeated;

  /// Changes the rules the player's next bullet points fly by, for a feature
  /// that changes how everyone's shots behave. The boss never touches the
  /// player itself.
  final void Function(ShotRules rules) setPlayerShotRules;

  static void _keepPlayerShots(ShotRules rules) {}

  /// Constrains where the player is drawn and collides -- snapping to a
  /// grid, say -- or frees it again with null.
  final void Function(PositionFilter? filter) setPlayerPositionFilter;

  static void _keepPlayerMoving(PositionFilter? filter) {}

  /// Hits the player with something that is not a shot, respecting its grace
  /// window like any shot would.
  final void Function() strikePlayer;

  static void _missPlayer() {}
}

/// A slide-editor feature, standing between the player and the end of the deck.
///
/// Every feature fights in its own way, so this holds only what the arena needs
/// in order to run a slide: where the fight stands, and how to end it. How a
/// boss is laid out, what it throws and how damage is distributed inside it are
/// entirely the boss's business.
abstract class Boss extends PositionComponent with CollisionCallbacks, HasAudio {
  Boss(this.context, {required Vector2 position, required Vector2 size})
    : super(position: position, size: size, anchor: Anchor.center);

  /// What the arena handed this feature when the slide started.
  final BossContext context;

  /// Where to throw things: the player's arena-local position.
  Vector2 aimAt() => context.aimAt();

  /// Ends the fight in the player's favour. Call once the feature is gone and
  /// any death animation has played.
  void onDefeated() => context.onDefeated();

  /// Hits still needed to finish the feature off. Zero means beaten.
  int get remainingHits;

  /// How many hits the fight started with, so progress can be shown.
  int get totalHits;

  /// The feature's own way of reporting its health -- a point size, a shape
  /// count -- in its own units rather than as a percentage.
  String get readout;

  bool get isDefeated;

  /// Every effect this feature plays, so the arena can load them before the
  /// fight starts. Each boss brings sounds of its own.
  Iterable<Cue> get cues;

  /// Called by the arena every time the player fires, for a feature that
  /// reacts to shooting as such. Most do not.
  void onPlayerFired() {}

  /// How the player leaves the slide if this feature wins.
  PlayerExit get playerExit => PlayerExit.spinOut;

  /// Applies [amount] hits. Exposed so a fight can be driven from tests
  /// without synthesising collisions.
  void takeHit([int amount = 1]);
}
