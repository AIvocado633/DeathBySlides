import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../components/arena_floor.dart';
import '../components/slide_painting.dart';
import '../theme/palette.dart';
import 'pep_talk.dart';

/// How shots behave under the rules a slide is currently played by.
///
/// Every shot starts under [standard]. A feature that changes the rules --
/// the Master Template, applying a theme -- hands shots a new set with
/// [Projectile.applyRules], and they change on the spot, in flight.
class ShotRules {
  const ShotRules({
    this.speed = 1,
    this.size = 1,
    this.bounces = 0,
    this.curve = 0,
  });

  /// The rules every shot starts under: its own speed and size, straight
  /// lines, and off the board at the first wall.
  static const standard = ShotRules();

  /// Multiplies the shot's own speed.
  final double speed;

  /// Multiplies the shot's own size, hitbox included.
  final double size;

  /// How many walls the shot bounces off before it leaves the board.
  final int bounces;

  /// How fast the shot turns, in radians a second. Shots alternate which way
  /// they turn, so a stream of them fans out rather than circling together.
  final double curve;
}

/// Shared behaviour for everything that flies across the arena.
///
/// Projectiles live in arena-local space as children of the [ArenaFloor], and
/// take themselves off the board as soon as they leave it.
abstract class Projectile extends PositionComponent with CollisionCallbacks {
  Projectile({
    required Vector2 position,
    required this.velocity,
    required double size,
  }) : super(
         position: position,
         size: Vector2.all(size),
         anchor: Anchor.center,
         // The hitbox is a constructor child rather than an `await add` in an
         // async onLoad, because an async onLoad defers mounting until the
         // event loop next turns. A projectile has to be live on the very next
         // frame, so it must load synchronously.
         children: [CircleHitbox(collisionType: CollisionType.passive)],
       );

  final Vector2 velocity;

  /// Hit points removed from whatever this hits.
  int get damage => 1;

  /// The rules this shot flies by now.
  ShotRules get rules => _rules;
  ShotRules _rules = ShotRules.standard;
  int _bouncesLeft = 0;

  /// Which way this shot turns when its rules curve.
  final double _curveSign = (_curveCount++).isEven ? 1 : -1;
  static int _curveCount = 0;

  /// Switches this shot to [rules] where it is: its speed and size change
  /// relative to its own, and it gets that many bounces afresh.
  void applyRules(ShotRules rules) {
    velocity.scale(rules.speed / _rules.speed);
    scale = Vector2.all(rules.size);
    _bouncesLeft = rules.bounces;
    _rules = rules;
  }

  /// Whether the shot is drawn pointing the way it travels. A spinning shot
  /// looks after its own angle.
  bool get pointsAlongVelocity => true;

  @override
  void onMount() {
    super.onMount();
    // Point the way it is travelling. With free aiming a shot can go anywhere,
    // and a bullet point flying north-west should point north-west.
    _pointAlong();
  }

  void _pointAlong() {
    if (pointsAlongVelocity) {
      angle = math.atan2(velocity.y, velocity.x);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_rules.curve != 0) {
      velocity.rotate(_rules.curve * _curveSign * dt);
      _pointAlong();
    }
    position += velocity * dt;

    final floor = parent;
    if (floor is ArenaFloor && !floor.size.toRect().contains(position.toOffset())) {
      if (_bouncesLeft > 0) {
        _bounceOff(floor);
      } else {
        removeFromParent();
      }
    }
  }

  /// Reflects off whichever wall was crossed, back onto the board.
  void _bounceOff(ArenaFloor floor) {
    _bouncesLeft--;
    if (position.x < 0 || position.x > floor.size.x) {
      velocity.x = -velocity.x;
    }
    if (position.y < 0 || position.y > floor.size.y) {
      velocity.y = -velocity.y;
    }
    position
      ..x = position.x.clamp(0, floor.size.x)
      ..y = position.y.clamp(0, floor.size.y);
    _pointAlong();
  }
}

/// Anything a feature throws at the player.
///
/// The player checks for this type rather than for a particular boss's
/// ammunition, so each new feature can bring its own without touching the
/// player.
abstract class EnemyShot extends Projectile {
  /// Pep Talk's slower shots are applied here, once, for every feature's
  /// ammunition: bosses throw at their own speed and never need to know.
  EnemyShot({
    required super.position,
    required super.velocity,
    required super.size,
  }) {
    velocity.scale(PepTalk.current.shotSpeedScale);
  }
}

/// Something a bullet point can be aimed at. Bosses mark whatever the player
/// is meant to hit, so aim assist finds it without knowing the boss.
mixin BulletTarget on PositionComponent {
  /// Whether it is still worth aiming at: false once broken or beaten.
  bool get isTargetable;
}

/// The player's shot: a bullet point, fired at the feature responsible.
class BulletPoint extends Projectile {
  BulletPoint({required super.position, required super.velocity})
    : super(size: 24);

  static const double speed = 640;

  /// How fast aim assist may turn a bullet point, in radians a second, and
  /// how far off its heading a target may be for it to try. Gentle on
  /// purpose: it rescues a near miss, it does not aim for you.
  static const double assistTurnRate = math.pi / 2;
  static const double assistCone = math.pi / 6;

  final Paint _paint = Paint()..color = Palette.brand;

  @override
  void update(double dt) {
    if (PepTalk.current.aimAssist) {
      _bendTowardsTarget(dt);
    }
    super.update(dt);
  }

  /// Turns towards the nearest target inside [assistCone], by at most
  /// [assistTurnRate] this frame.
  void _bendTowardsTarget(double dt) {
    final board = parent;
    if (board == null) {
      return;
    }
    final here = absolutePosition;
    final heading = math.atan2(velocity.y, velocity.x);
    double? best;
    var bestDistance = double.infinity;
    for (final target in board.descendants().whereType<BulletTarget>()) {
      if (!target.isTargetable) {
        continue;
      }
      final toTarget = target.absoluteCenter - here;
      final off = _wrap(math.atan2(toTarget.y, toTarget.x) - heading);
      final distance = toTarget.length;
      if (off.abs() <= assistCone && distance < bestDistance) {
        best = off;
        bestDistance = distance;
      }
    }
    if (best == null) {
      return;
    }
    final turn = best.clamp(-assistTurnRate * dt, assistTurnRate * dt);
    velocity.rotate(turn);
    angle = math.atan2(velocity.y, velocity.x);
  }

  static double _wrap(double radians) =>
      math.atan2(math.sin(radians), math.cos(radians));

  @override
  void render(Canvas canvas) {
    canvas.drawPath(trianglePath(Offset(width / 2, height / 2), width), _paint);
  }
}

/// The boss's shot: one of the little white squares an editor puts around a
/// selected shape, thrown at you so it can resize you down.
class ResizeHandle extends EnemyShot {
  ResizeHandle({required super.position, required super.velocity})
    : super(size: 20);

  static const double speed = 300;

  /// It spins as it flies, whatever its heading.
  @override
  bool get pointsAlongVelocity => false;

  final Paint _fill = Paint()..color = Palette.slide;
  final Paint _stroke = Paint()
    ..color = Palette.selection
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void update(double dt) {
    super.update(dt);
    angle += dt * 3;
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect().deflate(2);
    canvas.drawRect(rect, _fill);
    canvas.drawRect(rect, _stroke);
  }
}

/// The Diagram Wizard's shot: one of the connector arrows it draws between
/// shapes, sent at the player instead of at the next bullet in the list.
class ConnectorArrow extends EnemyShot {
  ConnectorArrow({required super.position, required super.velocity})
    : super(size: 30);

  static const double speed = 340;

  final Paint _paint = Paint()..color = Palette.diagramWizard;

  @override
  void render(Canvas canvas) {
    canvas.drawPath(
      blockArrowPath(Offset(width / 2, height / 2), width),
      _paint,
    );
  }
}
