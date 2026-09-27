import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/text.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../components/placeholder_frame.dart';
import '../components/shape_actor.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';
import 'boss.dart';
import 'health.dart';
import 'impact.dart';
import 'projectiles.dart';

/// The first boss: the feature that shrinks your text because it did not fit.
///
/// Its health *is* a font size. Every bullet point that lands steps it down the
/// same ladder of point sizes a slide editor walks when Shrink-to-Fit kicks in,
/// and the
/// boss is drawn smaller each time. Run it down to nothing and the feature has
/// shrunk itself out of existence.
class ShrinkToFitBoss extends Boss {
  /// Stands centred near the top of the arena and patrols from there.
  ShrinkToFitBoss(super.context)
    : super(
        position: Vector2(context.arenaSize.x / 2, 100),
        size: Vector2(220, 170),
      );

  /// The point sizes Shrink-to-Fit steps through, longest-standing first. One
  /// step per hit, so the ladder's length is the boss's hit points.
  static const List<int> pointLadder = [
    54,
    48,
    44,
    40,
    36,
    32,
    28,
    24,
    20,
    18,
    16,
    14,
  ];

  /// Seconds between thrown resize handles. Longer than the player's mercy
  /// window, so a single stream of shots always lands.
  static const double fireInterval = 1.5;
  static const double _patrolSpeed = 0.7;
  static const double _patrolReach = 150;

  late final Health health = Health(max: pointLadder.length, minScale: 0.35);

  /// The point size currently shown, or zero once the boss is finished.
  int get pointSize =>
      health.isDead ? 0 : pointLadder[pointLadder.length - health.current];

  @override
  int get remainingHits => health.current;

  @override
  int get totalHits => pointLadder.length;

  @override
  String get readout => '$pointSize pt';

  @override
  bool get isDefeated => _defeated;
  bool _defeated = false;

  double _sinceLastShot = 0;
  double _patrolPhase = 0;
  late final double _patrolOrigin = position.x;

  late final TextComponent _label;
  late final ShapeActor _actor;

  @override
  Future<void> onLoad() async {
    await addAll([
      PlaceholderFrame(
        position: Vector2.zero(),
        size: size.clone(),
        strokeColor: Palette.shrinkToFit,
      ),
      _actor = ShapeActor(
        artPrefix: 'shrink_to_fit_idle_',
        tint: Palette.shrinkToFit,
        position: Vector2(width / 2, 68),
        size: Vector2.all(104),
        anchor: Anchor.center,
      ),
      _label = TextComponent(
        text: '$pointSize pt',
        textRenderer: _labelRenderer(pointSize),
        position: Vector2(width / 2, height - 28),
        anchor: Anchor.center,
      ),
      RectangleHitbox(),
    ]);
  }

  static TextPaint _labelRenderer(int points) {
    return TextPaint(
      style: TextStyle(
        // The readout shrinks along with the number it is reporting.
        fontSize: 10 + points * 0.34,
        fontWeight: FontWeight.w700,
        color: Palette.slide,
        fontFamilyFallback: kFontStack,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_defeated) {
      return;
    }

    _patrolPhase += dt * _patrolSpeed;
    position.x = _patrolOrigin + math.sin(_patrolPhase) * _patrolReach;

    _sinceLastShot += dt;
    if (_sinceLastShot >= fireInterval) {
      _sinceLastShot = 0;
      _throwHandle();
    }
  }

  void _throwHandle() {
    final toTarget = aimAt() - position;
    if (toTarget.isZero()) {
      return;
    }
    parent?.add(
      ResizeHandle(
        position: position.clone(),
        velocity: toTarget.normalized() * ResizeHandle.speed,
      ),
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is! BulletPoint || _defeated) {
      return;
    }
    other.removeFromParent();
    takeHit(other.damage);
  }

  /// Steps the boss down the ladder. No mercy window: every bullet point in a
  /// stream should count.
  @override
  void takeHit([int amount = 1]) {
    if (_defeated) {
      return;
    }
    final before = pointSize;
    health.damage(amount);
    scale = Vector2.all(health.scale);
    _label
      ..text = '$pointSize pt'
      ..textRenderer = _labelRenderer(pointSize);

    // What the hit cost, in Shrink-to-Fit's own units: point sizes off the
    // ladder.
    Impact.hit(_actor);
    final floor = parent;
    if (floor != null && before > pointSize) {
      Impact.damage(
        floor,
        position - Vector2(0, scaledSize.y / 2),
        '−${before - pointSize} pt',
      );
    }

    if (health.isDead) {
      _defeated = true;
      _shrinkAway();
    }
  }

  /// Shrink-to-Fit's own medicine: shrink until there is nothing left to read.
  void _shrinkAway() {
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.45, curve: Curves.easeInBack),
        onComplete: () {
          removeFromParent();
          onDefeated();
        },
      ),
    );
  }
}
