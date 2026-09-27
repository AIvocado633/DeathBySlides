import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../audio/game_audio.dart';
import '../components/arena_floor.dart';
import '../components/shape_actor.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';
import 'boss.dart';
import 'health.dart';
import 'impact.dart';
import 'projectiles.dart';

/// The themes the Master Template forces on every slide, in turn.
///
/// Every theme is a trade-off for both sides, the way Shrink-to-Fit's
/// shrinking is: what makes your shots easier makes its shots harder, or the
/// other way round.
enum SlideTheme {
  /// The baseline: the game as tuned.
  plain(
    'Plain',
    player: ShotRules.standard,
    enemy: ShotRules.standard,
    floor: FloorLook.standard,
    accent: Palette.masterTemplate,
  ),

  /// Everything bounces off the walls once, bullet points included.
  rebound(
    'Rebound',
    player: ShotRules(bounces: 1),
    enemy: ShotRules(bounces: 1),
    floor: FloorLook(
      floor: Color(0xFF14241E),
      pattern: FloorPattern.stripes,
      patternColour: Color(0xFF28463A),
    ),
    accent: Color(0xFF3FA37A),
  ),

  /// Your shots are faster but thinner; its shots curve.
  sleek(
    'Sleek',
    player: ShotRules(speed: 1.4, size: 0.6),
    enemy: ShotRules(curve: 1.1),
    floor: FloorLook(
      floor: Color(0xFF1A1830),
      pattern: FloorPattern.dots,
      patternColour: Color(0xFF3A3566),
    ),
    accent: Color(0xFF7B6CD9),
  ),

  /// Everything is big and slow: easy to land, hard to dodge.
  chunky(
    'Chunky',
    player: ShotRules(speed: 0.6, size: 1.6),
    enemy: ShotRules(speed: 0.6, size: 1.6),
    floor: FloorLook(
      floor: Color(0xFF261D16),
      pattern: FloorPattern.checks,
      patternColour: Color(0xFF33271D),
    ),
    accent: Color(0xFFD9824A),
  );

  const SlideTheme(
    this.label, {
    required this.player,
    required this.enemy,
    required this.floor,
    required this.accent,
  });

  final String label;

  /// The rules the player's bullet points fly by under this theme.
  final ShotRules player;

  /// The rules the Master Template's shots fly by under this theme.
  final ShotRules enemy;

  final FloorLook floor;

  /// The colour the master and its layouts take on.
  final Color accent;

  SlideTheme get next => values[(index + 1) % values.length];
}

/// The third boss: the template every slide is built on, which changes
/// everything at once.
///
/// Shrink-to-Fit is one target that shrinks, and the Diagram Wizard is many
/// targets that move. The Master Template is one fight whose rules keep
/// changing -- for you as much as for it. Every [themeInterval] it applies a
/// new [SlideTheme] to the whole slide after a warning: the floor, how its
/// shots fly, how your shots fly, and every shot already in the air on both
/// sides changes in the same frame.
///
/// Its health is its layouts, hanging off the master. Each breaks after a few
/// hits and is stripped off; only then can the master itself be hit. Like the
/// real thing, it cannot be touched until everything built on it is gone.
class MasterTemplateBoss extends Boss {
  MasterTemplateBoss(super.context, {int? seed})
    : _random = math.Random(seed),
      super(
        position: Vector2(context.arenaSize.x / 2, 118),
        size: Vector2(760, 210),
      );

  final math.Random _random;

  static const int layoutCount = 5;
  static const int hitsPerLayout = 3;
  static const int masterHits = 4;

  /// Seconds between themes, and how much of that the warning takes. The
  /// warning is long enough to read at phone size and to get out of the way.
  static const double themeInterval = 7;
  static const double warningDuration = 1.6;

  /// Seconds between thrown swatches. Longer than the player's grace window,
  /// as for every boss.
  static const double fireInterval = 1.3;

  SlideTheme get theme => _theme;
  SlideTheme _theme = SlideTheme.plain;

  /// The warning on screen, while one is.
  ThemeWarning? get warning => _warning;
  ThemeWarning? _warning;

  late final TemplateThumb master;
  final List<TemplateThumb> layouts = [];

  List<TemplateThumb> get livingLayouts =>
      layouts.where((layout) => !layout.isBroken).toList();

  double _sinceTheme = 0;
  double _sinceShot = 0;

  @override
  int get remainingHits =>
      livingLayouts.fold(0, (sum, layout) => sum + layout.health.current) +
      (master.isBroken ? 0 : master.health.current);

  @override
  int get totalHits => layoutCount * hitsPerLayout + masterHits;

  @override
  String get readout => switch (livingLayouts.length) {
    0 => 'master only',
    1 => '1 layout',
    final count => '$count layouts',
  };

  @override
  bool get isDefeated => _defeated;
  bool _defeated = false;

  @override
  Iterable<Cue> get cues => const [
    Cue.templateHit,
    Cue.templateLayoutOff,
    Cue.themeWarning,
    Cue.themeApplied,
    Cue.templateClosed,
  ];

  @override
  Future<void> onLoad() async {
    master = TemplateThumb.master(
      position: Vector2(size.x / 2, 52),
      onBroken: _onMasterBroken,
    );
    const inset = 60.0;
    for (var i = 0; i < layoutCount; i++) {
      layouts.add(
        TemplateThumb.layout(
          position: Vector2(
            inset + (size.x - inset * 2) * i / (layoutCount - 1),
            size.y - 36,
          ),
          onBroken: _onLayoutBroken,
        ),
      );
    }
    await addAll([master, ...layouts]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_defeated) {
      return;
    }
    _sinceTheme += dt;
    if (_warning == null && _sinceTheme >= themeInterval - warningDuration) {
      _warn(_theme.next);
    }
    if (_sinceTheme >= themeInterval) {
      _sinceTheme = 0;
      applyTheme(_theme.next);
    }
    _sinceShot += dt;
    if (_sinceShot >= fireInterval) {
      _sinceShot = 0;
      _throwSwatch();
    }
  }

  void _warn(SlideTheme coming) {
    final floor = parent;
    if (floor is! ArenaFloor) {
      return;
    }
    audio.play(Cue.themeWarning);
    floor.add(
      _warning = ThemeWarning(
        theme: coming,
        duration: warningDuration,
        width: floor.size.x,
      ),
    );
  }

  /// Puts [theme] on the whole slide at once: the floor, the player's next
  /// shots, and every shot already in the air on both sides. Public so a
  /// test can change the rules without waiting for the timer.
  void applyTheme(SlideTheme theme) {
    _warning?.removeFromParent();
    _warning = null;
    _theme = theme;
    for (final thumb in [master, ...layouts]) {
      thumb.accent = theme.accent;
    }
    final floor = parent;
    if (floor is ArenaFloor) {
      floor.look = theme.floor;
      for (final shot in floor.children.whereType<Projectile>()) {
        shot.applyRules(shot is BulletPoint ? theme.player : theme.enemy);
      }
    }
    context.setPlayerShotRules(theme.player);
    if (!_defeated) {
      audio.play(Cue.themeApplied);
    }
  }

  void _throwSwatch() {
    final throwers = livingLayouts;
    final from = throwers.isEmpty
        ? master
        : throwers[_random.nextInt(throwers.length)];
    final origin = position - size / 2 + from.position;
    final toTarget = aimAt() - origin;
    if (toTarget.isZero()) {
      return;
    }
    parent?.add(
      SwatchShot(
        position: origin,
        velocity: toTarget.normalized() * SwatchShot.speed,
        colour: _theme.accent,
      )..applyRules(_theme.enemy),
    );
  }

  /// Takes [amount] hits off the layouts first, then off the master.
  @override
  void takeHit([int amount = 1]) {
    for (var i = 0; i < amount; i++) {
      final living = livingLayouts;
      if (living.isNotEmpty) {
        living.first.takeHit();
      } else if (!master.isBroken) {
        master.takeHit();
      }
    }
  }

  void _onLayoutBroken() {
    if (livingLayouts.isEmpty) {
      master.expose();
    }
  }

  /// Closing the template: the slide goes back to plain, for everyone.
  void _onMasterBroken() {
    _defeated = true;
    applyTheme(SlideTheme.plain);
    audio.play(Cue.templateClosed);
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.5, curve: Curves.easeInBack),
        onComplete: () {
          removeFromParent();
          onDefeated();
        },
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    // The layouts hang off the master the way they do in the template view.
    final paint = Paint()
      ..color = _theme.accent.withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final from = master.position + Vector2(0, master.size.y / 2);
    for (final layout in livingLayouts) {
      final to = layout.position - Vector2(0, layout.size.y / 2);
      final elbow = (from.y + to.y) / 2;
      canvas
        ..drawLine(from.toOffset(), Offset(from.x, elbow), paint)
        ..drawLine(Offset(from.x, elbow), Offset(to.x, elbow), paint)
        ..drawLine(Offset(to.x, elbow), to.toOffset(), paint);
    }
  }
}

/// A slide thumbnail in the template view: the master, or one of its layouts.
class TemplateThumb extends PositionComponent
    with CollisionCallbacks, HasAudio, BulletTarget {
  TemplateThumb.master({required super.position, required this.onBroken})
    : isMaster = true,
      health = Health(max: MasterTemplateBoss.masterHits, minScale: 0.7),
      _exposed = false,
      super(size: Vector2(150, 92), anchor: Anchor.center);

  TemplateThumb.layout({required super.position, required this.onBroken})
    : isMaster = false,
      health = Health(max: MasterTemplateBoss.hitsPerLayout, minScale: 0.7),
      _exposed = true,
      super(size: Vector2(96, 58), anchor: Anchor.center);

  final bool isMaster;
  final Health health;
  final void Function() onBroken;

  /// Whether shots can reach it. The master is shut away until its last
  /// layout is gone; shots meant for it until then fly straight past.
  bool get isExposed => _exposed;
  bool _exposed;

  bool get isBroken => _broken;
  bool _broken = false;

  Color accent = Palette.masterTemplate;

  ShapeActor? _actor;

  @override
  bool get isTargetable => _exposed && !_broken;

  @override
  Future<void> onLoad() async {
    await add(RectangleHitbox());
    if (isMaster) {
      await add(
        _actor = ShapeActor(
          actor: 'master_template',
          tint: Palette.masterTemplate,
          position: Vector2(size.x - 38, size.y / 2 + 6),
          size: Vector2.all(64),
          anchor: Anchor.center,
          bobbing: false,
        ),
      );
    }
  }

  /// Opens the master to hits, once its layouts are all gone.
  void expose() => _exposed = true;

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is! BulletPoint || !isTargetable) {
      return;
    }
    other.removeFromParent();
    takeHit(other.damage);
  }

  void takeHit([int amount = 1]) {
    if (_broken || !_exposed) {
      return;
    }
    health.damage(amount);
    final actor = _actor;
    if (!health.isDead) {
      Impact.hit(actor ?? this);
      actor?.hit();
      audio.play(Cue.templateHit);
      return;
    }
    // No squash on the breaking hit: a layout's own scale is about to run
    // down to nothing, and the two would fight over it.
    _broken = true;
    actor?.die();
    final board = parent?.parent;
    final boss = parent;
    if (board != null && boss is PositionComponent) {
      Impact.damage(
        board,
        boss.position - boss.size / 2 + position - Vector2(0, size.y / 2),
        isMaster ? '−master' : '−1 layout',
      );
    }
    onBroken();
    if (!isMaster) {
      audio.play(Cue.templateLayoutOff);
      // Stripped off: it drops away and is gone.
      addAll([
        MoveEffect.by(
          Vector2(0, 40),
          EffectController(duration: 0.3, curve: Curves.easeIn),
        ),
        ScaleEffect.to(
          Vector2.zero(),
          EffectController(duration: 0.3, curve: Curves.easeIn),
          onComplete: removeFromParent,
        ),
      ]);
    }
  }

  late final Paint _cardPaint = Paint()..color = Palette.slide;
  late final Paint _linePaint = Paint()..color = const Color(0xFFE2DCCF);
  final Paint _lockPaint = Paint()
    ..color = Palette.inkSoft
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  @override
  void render(Canvas canvas) {
    final card = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(6),
    );
    final edge = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = isMaster ? 4 : 3;
    canvas
      ..drawRRect(card, _cardPaint)
      ..drawRect(
        Rect.fromLTWH(8, 8, isMaster ? size.x * 0.46 : size.x - 16, 8),
        Paint()..color = accent,
      );
    for (final (i, fraction) in [0.7, 0.55, 0.62].indexed) {
      final width = (isMaster ? size.x * 0.5 : size.x - 16) * fraction;
      canvas.drawRect(Rect.fromLTWH(8, 26.0 + i * 12, width, 5), _linePaint);
    }
    canvas.drawRRect(card, edge);
    if (isMaster && !_exposed) {
      _drawLock(canvas, Offset(size.x - 14, 16));
    }
  }

  /// A small padlock: nothing on the master can be touched yet.
  void _drawLock(Canvas canvas, Offset at) {
    canvas
      ..drawRect(
        Rect.fromCenter(center: at.translate(0, 4), width: 12, height: 9),
        _lockPaint,
      )
      ..drawArc(
        Rect.fromCenter(center: at.translate(0, -1), width: 8, height: 10),
        math.pi,
        math.pi,
        false,
        _lockPaint,
      );
  }
}

/// The Master Template's shot: a colour swatch from the current theme.
class SwatchShot extends EnemyShot {
  SwatchShot({
    required super.position,
    required super.velocity,
    required this.colour,
  }) : super(size: 24);

  static const double speed = 300;

  final Color colour;

  late final Paint _fill = Paint()..color = colour;
  final Paint _edge = Paint()
    ..color = Palette.slide
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  @override
  void render(Canvas canvas) {
    final swatch = RRect.fromRectAndRadius(
      size.toRect().deflate(2),
      const Radius.circular(5),
    );
    canvas
      ..drawRRect(swatch, _fill)
      ..drawRRect(swatch, _edge);
  }
}

/// "Applying theme…": the warning across the top of the arena, with a bar
/// that fills until the new rules land. It fills at the fight's own pace, so
/// it stops with a paused fight like everything else on the floor.
class ThemeWarning extends PositionComponent {
  ThemeWarning({
    required this.theme,
    required this.duration,
    required double width,
  }) : super(size: Vector2(width, 44), priority: 5);

  final SlideTheme theme;
  final double duration;

  /// How full the bar is, 0 to 1.
  double get progress => (_elapsed / duration).clamp(0, 1);
  double _elapsed = 0;

  late final Paint _trackPaint = Paint()..color = const Color(0x33FFFFFF);
  late final Paint _barPaint = Paint()..color = theme.accent;

  @override
  Future<void> onLoad() async {
    await add(
      TextComponent(
        text: 'Applying theme “${theme.label}”…',
        textRenderer: SlideText.showBody,
        position: Vector2(16, 26),
        anchor: Anchor.centerLeft,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, width, 7), _trackPaint)
      ..drawRect(Rect.fromLTWH(0, 0, width * progress, 7), _barPaint);
  }
}
