import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

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
  });

  /// The size of the floor the fight happens on. Bosses work in arena-local
  /// coordinates, so this is where they place themselves.
  final Vector2 arenaSize;

  /// Where to throw things: the player's arena-local position.
  final Vector2 Function() aimAt;

  /// To be called once the feature is gone and any death animation has played.
  final void Function() onDefeated;
}

/// A slide-editor feature, standing between the player and the end of the deck.
///
/// Every feature fights in its own way, so this holds only what the arena needs
/// in order to run a slide: where the fight stands, and how to end it. How a
/// boss is laid out, what it throws and how damage is distributed inside it are
/// entirely the boss's business.
abstract class Boss extends PositionComponent with CollisionCallbacks {
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

  /// Applies [amount] hits. Exposed so a fight can be driven from tests
  /// without synthesising collisions.
  void takeHit([int amount = 1]);
}
