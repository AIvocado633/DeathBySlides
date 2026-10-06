import 'package:flame/components.dart';

/// The eight directions an actor can face.
///
/// Declared anticlockwise from east so that the index matches the octant of
/// `atan2(dy, dx)`, which keeps a facing a rounding away from the movement
/// vector. Screen y grows downwards, so "south" is the bottom of the slide.
enum Facing {
  east,
  southEast,
  south,
  southWest,
  west,
  northWest,
  north,
  northEast;

  /// True for the three directions with a westward component, i.e. the ones
  /// whose artwork is the mirror of the drawn pose.
  bool get isWestward =>
      this == Facing.southWest || this == Facing.west || this == Facing.northWest;

  /// Which of the five drawn directions this one is drawn with. The three
  /// westward ones borrow their eastern twin, mirrored.
  ArtDirection get drawnAs => switch (this) {
    Facing.south => ArtDirection.s,
    Facing.southEast || Facing.southWest => ArtDirection.se,
    Facing.east || Facing.west => ArtDirection.e,
    Facing.northEast || Facing.northWest => ArtDirection.ne,
    Facing.north => ArtDirection.n,
  };
}

/// The five directions directional art is drawn for.
enum ArtDirection { s, se, e, ne, n }

/// What an actor is doing, and so which frames it shows.
enum ActorState {
  /// Standing still. Every actor's fallback, and the only state an actor
  /// needs art for.
  idle,

  /// On the move.
  walk,

  /// Taking a hit: plays once, then back to whatever was playing before.
  hit,

  /// Going down: plays once and holds its last frame, so exit effects can run
  /// on top of it.
  die,

  /// Pleased with itself: loops, for the hero on a deck that has been
  /// presented.
  cheer;

  /// Whether the state plays once rather than looping.
  bool get isOneShot => this == hit || this == die;
}

/// The frames exported for one actor, and which of them to show when.
///
/// Frames are named `<actor>_<state>_000.png`, or `<actor>_<state>_<dir>_000.png`
/// for directional art. Asked for a state and a facing, the chain is:
///
/// 1. that state, drawn for that direction;
/// 2. that state, without a direction;
/// 3. idle, drawn for that direction;
/// 4. idle, without a direction.
///
/// So an actor with only idle frames shows them for everything, as before
/// states existed. Westward facings always mirror what they are given.
class ActorFrames {
  ActorFrames(this.actor, Map<String, List<Sprite>> frames)
    : _frames = Map.unmodifiable(frames);

  /// An actor with no frames at all, which draws its procedural stand-in.
  ActorFrames.none(this.actor) : _frames = const {};

  final String actor;
  final Map<String, List<Sprite>> _frames;

  /// The prefixes frames were found for.
  Set<String> get prefixes => _frames.keys.toSet();

  /// Whether this actor has real artwork. Idle is the end of every fallback
  /// chain, so without idle frames the stand-in is drawn throughout.
  bool get hasArtwork => resolve(actor, prefixes, ActorState.idle, Facing.south) != null;

  /// Every prefix an actor's frames might be exported under.
  static Iterable<String> candidatePrefixes(String actor) sync* {
    for (final state in ActorState.values) {
      yield prefixFor(actor, state);
      for (final direction in ArtDirection.values) {
        yield prefixFor(actor, state, direction);
      }
    }
  }

  static String prefixFor(
    String actor,
    ActorState state, [
    ArtDirection? direction,
  ]) => direction == null
      ? '${actor}_${state.name}_'
      : '${actor}_${state.name}_${direction.name}_';

  /// Which of [available] to show for [state] facing [facing], which state
  /// that art was drawn for, and whether to mirror it; null when not even
  /// idle is there.
  static ({String prefix, ActorState drawn, bool mirrored})? resolve(
    String actor,
    Set<String> available,
    ActorState state,
    Facing facing,
  ) {
    final direction = facing.drawnAs;
    for (final wanted in {state, ActorState.idle}) {
      for (final prefix in [
        prefixFor(actor, wanted, direction),
        prefixFor(actor, wanted),
      ]) {
        if (available.contains(prefix)) {
          return (prefix: prefix, drawn: wanted, mirrored: facing.isWestward);
        }
      }
    }
    return null;
  }

  final Map<(String, double), SpriteAnimation> _animations = {};

  /// The animation to play for [state] facing [facing], built once per
  /// prefix and step time. One-shot states do not loop, so `die` holds its
  /// last frame.
  ({SpriteAnimation animation, String prefix, bool loops, bool mirrored})?
  animationFor(
    ActorState state,
    Facing facing, {
    required double stepTime,
  }) {
    final found = resolve(actor, prefixes, state, facing);
    if (found == null) {
      return null;
    }
    // Only art drawn for a one-shot plays once. Idle standing in for a
    // missing hit keeps looping, so an actor with only idle frames looks
    // exactly as it did before it had states.
    final loop = !found.drawn.isOneShot;
    final animation = _animations.putIfAbsent(
      ('${found.prefix}${loop ? '' : '!'}', stepTime),
      () => SpriteAnimation.spriteList(
        _frames[found.prefix]!,
        stepTime: stepTime,
        loop: loop,
      ),
    );
    return (
      animation: animation,
      prefix: found.prefix,
      loops: loop,
      mirrored: found.mirrored,
    );
  }
}
