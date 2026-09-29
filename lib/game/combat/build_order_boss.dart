import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../audio/game_audio.dart';
import '../components/slide_painting.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';
import 'boss.dart';
import 'build_queue.dart';
import 'health.dart';
import 'impact.dart';
import 'projectiles.dart';

export 'build_queue.dart';

Color _starColour(EffectKind kind) => switch (kind) {
  EffectKind.entrance => Palette.entranceStar,
  EffectKind.emphasis => Palette.emphasisStar,
  EffectKind.exit => Palette.exitStar,
};

/// The fourth boss: the list of effects that plays in an order nobody can
/// predict.
///
/// The Build Order docks beside the arena and lists the attacks to come, in
/// order, each with a trigger ([BuildQueue] has the rules). On Click is the
/// catch: **every bullet point fired is a click**, so holding the aim down
/// sets off every On Click attack in the queue. The other fights reward
/// shooting all the time; this one rewards reading the queue and choosing
/// when.
///
/// Its health is the list. Every step has a numbered tag floating over the
/// arena, and shooting a tag down deletes its step. Every few deletions the
/// queue reorders itself, so the list being read changes underneath you.
/// Emptied, it is beaten.
class BuildOrderBoss extends Boss {
  BuildOrderBoss(super.context, {int? seed, List<BuildStep>? steps})
    : _random = math.Random(seed),
      queue = BuildQueue(steps ?? BuildQueue.opening()),
      super(
        // Covers the arena exactly, so its local space is the arena's.
        position: context.arenaSize / 2,
        size: context.arenaSize.clone(),
      );

  final math.Random _random;

  /// The steps and the rules for when each plays.
  final BuildQueue queue;

  static const int hitsPerTag = 2;

  /// How many deletions before the queue reorders itself.
  static const int reorderEvery = 3;

  late final BuildPane pane;

  /// The tags floating over the arena, one per step still in the queue.
  List<BuildTag> get tags =>
      children.whereType<BuildTag>().where((tag) => !tag.isDeleted).toList();

  late final int _openingLength = queue.length;
  int _deleted = 0;
  bool _clicked = false;

  /// How many times the queue has reordered itself.
  int get reorders => _reorders;
  int _reorders = 0;

  @override
  int get remainingHits =>
      tags.fold(0, (sum, tag) => sum + tag.health.current);

  @override
  int get totalHits => _openingLength * hitsPerTag;

  @override
  String get readout =>
      queue.length == 1 ? '1 animation' : '${queue.length} animations';

  @override
  bool get isDefeated => _defeated;
  bool _defeated = false;

  /// Losing to it plays the player's exit: flying out, off the slide.
  @override
  PlayerExit get playerExit => PlayerExit.flyOut;

  @override
  Iterable<Cue> get cues => const [
    Cue.buildTagHit,
    Cue.buildStepDeleted,
    Cue.buildReorder,
    Cue.buildStepStarted,
    Cue.buildEmptied,
  ];

  @override
  void onPlayerFired() => _clicked = true;

  @override
  Future<void> onLoad() async {
    await add(
      pane = BuildPane(
        queue: queue,
        // Docked in the slide's margin beside the arena, so the whole floor
        // stays playable.
        position: Vector2(size.x + 12, 0),
      ),
    );
    await addAll([
      for (final step in queue.steps)
        BuildTag(
          step: step,
          position: _freeSpot(),
          velocity: _drift(),
          onDeleted: _onTagDeleted,
        ),
    ]);
    _renumber();
  }

  /// Where tags float: the upper part of the arena, clear of the edges.
  Rect get tagArea => Rect.fromLTWH(40, 40, size.x - 80, size.y * 0.55);

  Vector2 _freeSpot() => Vector2(
    tagArea.left + _random.nextDouble() * tagArea.width,
    tagArea.top + _random.nextDouble() * tagArea.height,
  );

  Vector2 _drift() =>
      Vector2(0, 1)..rotate(_random.nextDouble() * math.pi * 2)..scale(28);

  /// Seconds left before an emptied queue leaves the slide.
  double _closingIn = 0;
  bool _closed = false;
  static const double _closingTime = 0.5;

  @override
  void update(double dt) {
    super.update(dt);
    if (_defeated) {
      // Counted here rather than with a timer component, so the exit starts
      // on the very next frame.
      _closingIn -= dt;
      if (_closingIn <= 0 && !_closed) {
        _closed = true;
        removeFromParent();
        onDefeated();
      }
      return;
    }
    final started = queue.update(dt, clicked: _clicked);
    _clicked = false;
    for (final step in started) {
      audio.play(Cue.buildStepStarted);
      add(_attackFor(step.effect));
    }
  }

  /// Deletes a step, as if its tag had been shot down. Public for tests.
  void deleteStep(int id) {
    final tag = tags.where((tag) => tag.step.id == id).firstOrNull;
    if (tag == null) {
      return;
    }
    tag.takeHit(tag.health.current);
  }

  /// Takes [amount] hits off the tag of the step that plays next.
  @override
  void takeHit([int amount = 1]) {
    for (var i = 0; i < amount; i++) {
      final next = queue.next;
      if (next == null) {
        return;
      }
      tags.firstWhere((tag) => tag.step.id == next.id).takeHit();
    }
  }

  void _onTagDeleted(BuildTag tag) {
    queue.remove(tag.step.id);
    _deleted++;
    if (queue.isEmpty) {
      _empty();
      return;
    }
    if (_deleted % reorderEvery == 0) {
      queue.reorder(_random);
      _reorders++;
      audio.play(Cue.buildReorder);
      pane.flash();
    }
    _renumber();
  }

  /// Each tag shows where its step stands in the queue now.
  void _renumber() {
    final order = {for (final (i, step) in queue.steps.indexed) step.id: i + 1};
    for (final tag in tags) {
      tag.number = order[tag.step.id] ?? 0;
    }
  }

  void _empty() {
    _defeated = true;
    _closingIn = _closingTime;
    audio.play(Cue.buildEmptied);
    pane.add(
      ScaleEffect.to(
        Vector2(1, 0),
        EffectController(duration: _closingTime, curve: Curves.easeIn),
      ),
    );
  }

  Component _attackFor(BuildEffect effect) => switch (effect) {
    BuildEffect.flyIn => _FlyIn(_random),
    BuildEffect.spin => _Spin(),
    BuildEffect.pulse => _Pulse(_random),
    BuildEffect.wipe => _Wipe(_random),
    BuildEffect.bounce => _Bounce(),
    BuildEffect.wobble => _Wobble(),
  };

  /// Adds a shot in [effect]'s colour to the board.
  void throwShot(Vector2 from, Vector2 velocity, EffectKind kind) {
    parent?.add(
      BuildShot(position: from, velocity: velocity, kind: kind),
    );
  }
}

/// The docked list of steps to come, with the one playing next on top.
class BuildPane extends PositionComponent {
  BuildPane({required this.queue, required super.position})
    : super(size: Vector2(162, 326));

  final BuildQueue queue;

  static const int visibleRows = 7;
  static const double _headerHeight = 36;
  static const double _rowHeight = 40;

  final Paint _backgroundPaint = Paint()..color = Palette.toolbar;
  final Paint _edgePaint = Paint()
    ..color = Palette.buildOrder
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _nextPaint = Paint()..color = const Color(0x333A6FD8);
  final Paint _flashPaint = Paint()..color = const Color(0x55FFFFFF);

  double _flash = 0;

  /// A brief glow when the queue reorders itself.
  void flash() => _flash = 0.35;

  @override
  void update(double dt) {
    super.update(dt);
    _flash = math.max(0, _flash - dt);
  }

  @override
  void render(Canvas canvas) {
    final card = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(8));
    canvas.drawRRect(card, _backgroundPaint);
    SlideText.paneTitle.render(
      canvas,
      'Build Order',
      Vector2(12, _headerHeight / 2),
      anchor: Anchor.centerLeft,
    );
    final steps = queue.steps;
    final rows = math.min(visibleRows, steps.length);
    for (var row = 0; row < rows; row++) {
      final index = (queue.cursor + row) % steps.length;
      final step = steps[index];
      final top = _headerHeight + row * _rowHeight;
      if (row == 0) {
        canvas.drawRect(Rect.fromLTWH(2, top, width - 4, _rowHeight), _nextPaint);
      }
      SlideText.paneStep.render(
        canvas,
        '${index + 1}',
        Vector2(12, top + 13),
        anchor: Anchor.centerLeft,
      );
      canvas.drawPath(
        starPath(Offset(44, top + 13), 7),
        Paint()..color = _starColour(step.effect.kind),
      );
      SlideText.paneStep.render(
        canvas,
        step.effect.label,
        Vector2(58, top + 13),
        anchor: Anchor.centerLeft,
      );
      SlideText.paneTrigger.render(
        canvas,
        step.trigger.label,
        Vector2(58, top + 31),
        anchor: Anchor.centerLeft,
      );
    }
    if (_flash > 0) {
      canvas.drawRRect(card, _flashPaint);
    }
    canvas.drawRRect(card, _edgePaint);
  }
}

/// A step's numbered tag, floating over the arena. Shoot it down to delete
/// the step.
class BuildTag extends PositionComponent
    with CollisionCallbacks, HasAudio, BulletTarget {
  BuildTag({
    required this.step,
    required super.position,
    required this.velocity,
    required this.onDeleted,
  }) : super(size: Vector2.all(44), anchor: Anchor.center);

  final BuildStep step;
  final Vector2 velocity;
  final void Function(BuildTag tag) onDeleted;

  final Health health = Health(max: BuildOrderBoss.hitsPerTag, minScale: 0.8);

  /// Where the step stands in the queue, as shown on the tag.
  int number = 0;

  bool get isDeleted => _deleted;
  bool _deleted = false;

  @override
  bool get isTargetable => !_deleted;

  @override
  Future<void> onLoad() async {
    await add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_deleted) {
      return;
    }
    position += velocity * dt;
    final boss = parent;
    if (boss is BuildOrderBoss) {
      final area = boss.tagArea;
      if (position.x < area.left || position.x > area.right) {
        velocity.x = -velocity.x;
      }
      if (position.y < area.top || position.y > area.bottom) {
        velocity.y = -velocity.y;
      }
      position
        ..x = position.x.clamp(area.left, area.right)
        ..y = position.y.clamp(area.top, area.bottom);
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is! BulletPoint || _deleted) {
      return;
    }
    other.removeFromParent();
    takeHit(other.damage);
  }

  void takeHit([int amount = 1]) {
    if (_deleted) {
      return;
    }
    health.damage(amount);
    if (!health.isDead) {
      Impact.hit(this);
      audio.play(Cue.buildTagHit);
      return;
    }
    _deleted = true;
    audio.play(Cue.buildStepDeleted);
    final board = parent?.parent;
    if (board != null) {
      Impact.damage(board, position - Vector2(0, size.y / 2), '−1 animation');
    }
    onDeleted(this);
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.25, curve: Curves.easeIn),
        onComplete: removeFromParent,
      ),
    );
  }

  late final Paint _fill = Paint()..color = Palette.slide;
  late final Paint _ring = Paint()
    ..color = _starColour(step.effect.kind)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;

  @override
  void render(Canvas canvas) {
    final centre = Offset(width / 2, height / 2);
    canvas
      ..drawCircle(centre, width / 2, _fill)
      ..drawCircle(centre, width / 2 - 2, _ring);
    SlideText.tagNumber.render(
      canvas,
      '$number',
      Vector2(width / 2, height / 2),
      anchor: Anchor.center,
    );
  }
}

/// A shot from a build step: a small star in the colour of its effect.
class BuildShot extends EnemyShot {
  BuildShot({
    required super.position,
    required super.velocity,
    required this.kind,
  }) : super(size: 22);

  final EffectKind kind;

  late final Paint _paint = Paint()..color = _starColour(kind);

  @override
  void render(Canvas canvas) {
    canvas.drawPath(starPath(Offset(width / 2, height / 2), width / 2), _paint);
  }
}

/// One step's attack, playing out over its effect's duration. A child of the
/// boss, so it pauses with the fight and stops if the boss is beaten.
abstract class _Attack extends Component with ParentIsA<BuildOrderBoss> {
  _Attack(this.effect);

  final BuildEffect effect;
  double _elapsed = 0;

  BuildOrderBoss get boss => parent;
  Vector2 get arena => boss.size;
  Vector2 get player => boss.aimAt();

  @override
  void update(double dt) {
    super.update(dt);
    final before = _elapsed;
    _elapsed += dt;
    play(before, _elapsed);
    if (_elapsed >= effect.duration) {
      removeFromParent();
    }
  }

  /// Throws whatever falls due between [from] and [to] seconds in.
  void play(double from, double to);

  /// Whether a moment [at] seconds in fell inside this frame.
  static bool due(double at, double from, double to) => from <= at && at < to;

  void shoot(Vector2 from, Vector2 velocity) =>
      boss.throwShot(from, velocity, effect.kind);
}

/// Shots sweep in from one edge, in two waves.
class _FlyIn extends _Attack {
  _FlyIn(math.Random random)
    : _edge = random.nextInt(3),
      super(BuildEffect.flyIn);

  final int _edge;
  static const double _speed = 260;

  @override
  void play(double from, double to) {
    for (final wave in [0.0, 0.6]) {
      if (!_Attack.due(wave, from, to)) {
        continue;
      }
      for (var i = 0; i < 6; i++) {
        final t = (i + 0.5 + (wave > 0 ? 0.5 : 0)) / 6.5;
        switch (_edge) {
          case 0:
            shoot(Vector2(4, arena.y * t), Vector2(_speed, 0));
          case 1:
            shoot(Vector2(arena.x - 4, arena.y * t), Vector2(-_speed, 0));
          default:
            shoot(Vector2(arena.x * t, 4), Vector2(0, _speed));
        }
      }
    }
  }
}

/// A rotating spiral from the top middle of the arena.
class _Spin extends _Attack {
  _Spin() : super(BuildEffect.spin);

  static const double _every = 0.1;
  static const double _speed = 210;

  @override
  void play(double from, double to) {
    for (var at = (from / _every).ceil() * _every; at < to; at += _every) {
      final angle = at * 4.2;
      shoot(
        Vector2(arena.x / 2, 50),
        Vector2(math.cos(angle), math.sin(angle).abs() + 0.2)..scale(_speed),
      );
    }
  }
}

/// A ring of shots expanding from above the player, with a gap to slip out
/// through.
class _Pulse extends _Attack {
  _Pulse(this._random) : super(BuildEffect.pulse);

  final math.Random _random;
  static const int _count = 18;
  static const int _gap = 3;

  @override
  void play(double from, double to) {
    if (!_Attack.due(0, from, to)) {
      return;
    }
    final centre = Vector2(player.x, math.max(60, player.y - 170));
    final gapStart = _random.nextInt(_count);
    for (var i = 0; i < _count; i++) {
      if ((i - gapStart) % _count < _gap) {
        continue;
      }
      final angle = i * math.pi * 2 / _count;
      shoot(centre.clone(), Vector2(math.cos(angle), math.sin(angle))..scale(190));
    }
  }
}

/// A wall of shots crossing the arena from the left, with one way through.
class _Wipe extends _Attack {
  _Wipe(this._random) : super(BuildEffect.wipe);

  final math.Random _random;
  static const double _spacing = 32;

  @override
  void play(double from, double to) {
    if (!_Attack.due(0, from, to)) {
      return;
    }
    final slots = (arena.y / _spacing).floor();
    final gap = 1 + _random.nextInt(slots - 4);
    for (var i = 0; i < slots; i++) {
      if (i >= gap && i < gap + 3) {
        continue;
      }
      shoot(Vector2(6, (i + 0.5) * _spacing), Vector2(230, 0));
    }
  }
}

/// Three shots at the player that bounce off the walls twice.
class _Bounce extends _Attack {
  _Bounce() : super(BuildEffect.bounce);

  static const _rules = ShotRules(bounces: 2);

  @override
  void play(double from, double to) {
    if (!_Attack.due(0, from, to)) {
      return;
    }
    final from0 = Vector2(arena.x / 2, 40);
    final aim = player - from0;
    if (aim.isZero()) {
      return;
    }
    for (final spread in [-0.35, 0.0, 0.35]) {
      final velocity = aim.normalized()
        ..rotate(spread)
        ..scale(250);
      boss.parent?.add(
        BuildShot(position: from0.clone(), velocity: velocity, kind: effect.kind)
          ..applyRules(_rules),
      );
    }
  }
}

/// A stream aimed at the player that wobbles as it comes.
class _Wobble extends _Attack {
  _Wobble() : super(BuildEffect.wobble);

  static const double _every = 0.22;
  static const _rules = ShotRules(curve: 1.4);

  @override
  void play(double from, double to) {
    for (var at = (from / _every).ceil() * _every; at < to; at += _every) {
      final origin = Vector2(arena.x / 2, 40);
      final aim = player - origin;
      if (aim.isZero()) {
        continue;
      }
      boss.parent?.add(
        BuildShot(
          position: origin,
          velocity: aim.normalized()..scale(240),
          kind: effect.kind,
        )..applyRules(_rules),
      );
    }
  }
}
