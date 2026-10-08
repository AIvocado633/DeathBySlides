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
class BuildOrderBoss extends Boss implements BuildStage {
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

  Component _attackFor(BuildEffect effect) =>
      BuildAttack.of(effect, stage: this, random: _random);

  /// It covers the arena exactly, so its own size is the arena's.
  @override
  Vector2 get arena => size;

  @override
  void throwShot(
    Vector2 from,
    Vector2 velocity,
    EffectKind kind, {
    ShotRules rules = ShotRules.standard,
  }) {
    parent?.add(
      BuildShot(position: from, velocity: velocity, kind: kind)
        ..applyRules(rules),
    );
  }
}

/// Where build steps play out: the arena an attack aims across, and how its
/// shots reach the board. The Build Order is one stage; any fight that plays
/// build effects is another.
abstract interface class BuildStage {
  /// The size of the arena, in the same arena-local units shots fly in.
  Vector2 get arena;

  /// The player's arena-local position.
  Vector2 aimAt();

  /// Adds a shot in the colour of an effect of [kind] to the board.
  void throwShot(
    Vector2 from,
    Vector2 velocity,
    EffectKind kind, {
    ShotRules rules = ShotRules.standard,
  });
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

/// One step's attack, playing out over its effect's duration. Added under
/// the boss playing it, so it pauses with the fight and stops if the boss is
/// beaten.
abstract class BuildAttack extends Component {
  BuildAttack(this.effect, this.stage);

  /// The attack named after [effect], played on [stage].
  factory BuildAttack.of(
    BuildEffect effect, {
    required BuildStage stage,
    required math.Random random,
  }) => switch (effect) {
    BuildEffect.flyIn => _FlyIn(stage, random),
    BuildEffect.spin => _Spin(stage),
    BuildEffect.pulse => _Pulse(stage, random),
    BuildEffect.wipe => _Wipe(stage, random),
    BuildEffect.bounce => _Bounce(stage),
    BuildEffect.wobble => _Wobble(stage),
  };

  final BuildEffect effect;
  final BuildStage stage;
  double _elapsed = 0;

  /// The narrowest way through any attack: a full-size player (120 across),
  /// one shot, and room to steer. An attack that leaves less is a hit
  /// nobody can dodge.
  static const double lane = 170;

  Vector2 get arena => stage.arena;
  Vector2 get player => stage.aimAt();

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

  void shoot(
    Vector2 from,
    Vector2 velocity, {
    ShotRules rules = ShotRules.standard,
  }) => stage.throwShot(from, velocity, effect.kind, rules: rules);
}

/// Two walls of shots sweep in from one edge, each with a lane through it.
/// The second wall's lane is a short step from the first's, close enough to
/// reach in the time between them.
class _FlyIn extends BuildAttack {
  _FlyIn(BuildStage stage, math.Random random)
    : _random = random,
      _edge = random.nextInt(3),
      super(BuildEffect.flyIn, stage);

  final math.Random _random;
  final int _edge;
  static const double _speed = 260;
  static const double _spacing = 50;

  /// Slots left empty: with the shots either side, a lane of
  /// (3 + 1) x 50 - 22 = 178.
  static const int _laneSlots = 3;
  static const double _between = 0.6;

  int _lane = 0;

  @override
  void play(double from, double to) {
    for (final (index, wave) in [0.0, _between].indexed) {
      if (!BuildAttack.due(wave, from, to)) {
        continue;
      }
      final extent = _edge == 2 ? arena.x : arena.y;
      final slots = (extent / _spacing).floor();
      final last = slots - _laneSlots;
      _lane = index == 0
          ? _random.nextInt(last + 1)
          : (_lane + (_random.nextBool() ? 2 : -2)).clamp(0, last);
      for (var i = 0; i < slots; i++) {
        if (i >= _lane && i < _lane + _laneSlots) {
          continue;
        }
        final along = (i + 0.5) * _spacing;
        switch (_edge) {
          case 0:
            shoot(Vector2(4, along), Vector2(_speed, 0));
          case 1:
            shoot(Vector2(arena.x - 4, along), Vector2(-_speed, 0));
          default:
            shoot(Vector2(along, 4), Vector2(0, _speed));
        }
      }
    }
  }
}

/// A rotating spiral from the top middle of the arena.
class _Spin extends BuildAttack {
  _Spin(BuildStage stage) : super(BuildEffect.spin, stage);

  /// Far enough apart that the arms of the spiral have room between them
  /// where the player stands.
  static const double _every = 0.14;
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

/// A ring of shots expanding from a fixed distance above the player (below,
/// near the top of the arena), with a gap facing the player to slip out
/// through.
class _Pulse extends BuildAttack {
  _Pulse(BuildStage stage, this._random) : super(BuildEffect.pulse, stage);

  final math.Random _random;
  static const int _count = 18;
  static const int _gap = 4;

  /// How far from the player the ring starts. The gap is measured here.
  static const double reach = 170;

  @override
  void play(double from, double to) {
    if (!BuildAttack.due(0, from, to)) {
      return;
    }
    final above = player.y - reach >= 30;
    final centre = Vector2(player.x, player.y + (above ? -reach : reach));
    // The gap opens towards the player, with the player at least two shots
    // from either side of it.
    final facing = math.atan2(player.y - centre.y, player.x - centre.x);
    final slot = (facing / (math.pi * 2 / _count)).round();
    final gapStart = slot - 1 - _random.nextInt(_gap - 2);
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
class _Wipe extends BuildAttack {
  _Wipe(BuildStage stage, this._random) : super(BuildEffect.wipe, stage);

  final math.Random _random;
  static const double _spacing = 32;

  /// Slots left empty: with the shots either side, a lane of
  /// (6 + 1) x 32 - 22 = 202.
  static const int _laneSlots = 6;

  @override
  void play(double from, double to) {
    if (!BuildAttack.due(0, from, to)) {
      return;
    }
    final slots = (arena.y / _spacing).floor();
    final gap = _random.nextInt(slots - _laneSlots + 1);
    for (var i = 0; i < slots; i++) {
      if (i >= gap && i < gap + _laneSlots) {
        continue;
      }
      shoot(Vector2(6, (i + 0.5) * _spacing), Vector2(230, 0));
    }
  }
}

/// Three shots at the player that bounce off the walls twice.
class _Bounce extends BuildAttack {
  _Bounce(BuildStage stage) : super(BuildEffect.bounce, stage);

  static const _rules = ShotRules(bounces: 2);

  @override
  void play(double from, double to) {
    if (!BuildAttack.due(0, from, to)) {
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
      shoot(from0.clone(), velocity, rules: _rules);
    }
  }
}

/// A stream aimed at the player that wobbles as it comes.
class _Wobble extends BuildAttack {
  _Wobble(BuildStage stage) : super(BuildEffect.wobble, stage);

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
      shoot(origin, aim.normalized()..scale(240), rules: _rules);
    }
  }
}
