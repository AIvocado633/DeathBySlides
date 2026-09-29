import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../audio/game_audio.dart';
import '../components/arena_floor.dart';
import '../components/shape_actor.dart';
import '../components/slide_painting.dart';
import '../slide/motion.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';
import 'boss.dart';
import 'impact.dart';
import 'pep_talk.dart';
import 'projectiles.dart';

/// The fifth boss: the setting that puts everything almost where you wanted
/// it.
///
/// Here the arena is the enemy. While it is on, **the player snaps**: input
/// stays analogue, but the player lands on the nearest grid crossing, so
/// movement becomes a series of deliberate hops. The boss roams the arena as
/// a small grid dialog, marks rows and columns with alignment guides, and
/// strikes along them. Snapped, you are always on a line, so dodging means
/// reaching a different line in time.
///
/// Its health is the grid spacing. It starts coarse -- few lanes, chunky
/// hops -- and every few hits the grid gets finer: more lanes to watch, but
/// smoother movement. Run the spacing out and snapping is off. As with
/// Shrink-to-Fit's shrinking, winning changes how you move.
class SnapToGridBoss extends Boss with BulletTarget {
  SnapToGridBoss(super.context, {int? seed})
    : _random = math.Random(seed),
      super(
        position: Vector2(context.arenaSize.x / 2, 90),
        size: Vector2(176, 104),
      );

  final math.Random _random;

  /// The spacings the grid steps down through, in centimetres, coarse first.
  static const List<double> spacingsCm = [2, 1.5, 1.25, 1, 0.75, 0.5, 0.25];

  /// Slide units to a centimetre of grid spacing.
  static const double unitsPerCm = 60;

  static const int hitsPerSpacing = 3;

  /// Seconds between volleys of guides.
  static const double volleyInterval = 2.4;

  /// How long guides show before they strike. Stretched by Pep Talk's slower
  /// shots, since a guide is this fight's shot.
  static const double warningTime = 1.2;
  static double get warning => warningTime / PepTalk.current.shotSpeedScale;

  /// How fast the dialog roams, before it too snaps to the grid.
  static const double roamSpeed = 70;

  int _step = 0;
  int _hitsThisSpacing = 0;

  /// The spacing in force, in centimetres, or null once snapping is off.
  double? get spacingCm => _step < spacingsCm.length ? spacingsCm[_step] : null;

  /// The spacing in force, in slide units.
  double get spacing => (spacingCm ?? 1) * unitsPerCm;

  late final Vector2 _intended = position.clone();
  late final Vector2 _roam = Vector2(1, 0.6)..scale(roamSpeed);
  double _sinceVolley = 0;
  late final ShapeActor _actor;

  @override
  int get remainingHits =>
      (spacingsCm.length - _step) * hitsPerSpacing - _hitsThisSpacing;

  @override
  int get totalHits => spacingsCm.length * hitsPerSpacing;

  @override
  String get readout => spacingCm == null ? 'Off' : 'Spacing $_spacingLabel';

  /// The spacing as the dialog writes it: `2 cm`, `0.25 cm`, or `Off`.
  String get _spacingLabel {
    final cm = spacingCm;
    if (cm == null) {
      return 'Off';
    }
    return '${cm == cm.roundToDouble() ? cm.round() : cm} cm';
  }

  @override
  bool get isDefeated => _defeated;
  bool _defeated = false;

  @override
  bool get isTargetable => !_defeated;

  @override
  Iterable<Cue> get cues => const [
    Cue.guideWarning,
    Cue.guideStrike,
    Cue.snapHit,
    Cue.gridFiner,
    Cue.snapOff,
  ];

  ArenaFloor? get _floor {
    final floor = parent;
    return floor is ArenaFloor ? floor : null;
  }

  @override
  Future<void> onLoad() async {
    await addAll([
      RectangleHitbox(),
      _actor = ShapeActor(
        actor: 'snap_to_grid',
        tint: Palette.snapToGrid,
        position: Vector2(size.x - 34, size.y / 2 + 12),
        size: Vector2.all(56),
        anchor: Anchor.center,
        bobbing: false,
      ),
    ]);
  }

  @override
  void onMount() {
    super.onMount();
    _applySpacing();
  }

  /// One spacing drives both the grid the floor draws and the grid the
  /// player snaps to, so what you see is what you snap to.
  void _applySpacing() {
    final floor = _floor;
    if (floor == null) {
      return;
    }
    if (spacingCm == null) {
      floor.setGrid(spacing: ArenaFloor.standardGridSpacing);
      context.setPlayerPositionFilter(null);
      return;
    }
    floor.setGrid(spacing: spacing, origin: floor.centre);
    context.setPlayerPositionFilter(floor.snapToGrid);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_defeated) {
      return;
    }
    _wander(dt);
    _sinceVolley += dt;
    if (_sinceVolley >= volleyInterval) {
      _sinceVolley = 0;
      _markGuides();
    }
  }

  /// Roams the upper arena, bouncing off its edges -- and snaps as well.
  void _wander(double dt) {
    final floor = _floor;
    if (floor == null) {
      return;
    }
    _intended.add(_roam * dt);
    final half = size / 2;
    final bottom = floor.size.y * 0.45;
    if (_intended.x < half.x || _intended.x > floor.size.x - half.x) {
      _roam.x = -_roam.x;
    }
    if (_intended.y < half.y || _intended.y > bottom) {
      _roam.y = -_roam.y;
    }
    _intended
      ..x = _intended.x.clamp(half.x, floor.size.x - half.x)
      ..y = _intended.y.clamp(half.y, bottom);
    position.setFrom(floor.snapToGrid(_intended, size));
  }

  /// Marks a few lines with guides: always the player's own row or column,
  /// and more lanes the finer the grid.
  void _markGuides() {
    final floor = _floor;
    if (floor == null) {
      return;
    }
    final player = aimAt();
    final count = math.min(1 + _step ~/ 2, 4);
    final chosen = <(bool, double)>{};
    final ownRow = _random.nextBool();
    chosen.add((ownRow, ownRow ? player.y : player.x));
    for (var tries = 0; chosen.length < count && tries < 20; tries++) {
      final rows = _random.nextBool();
      final lines = floor.gridLines(rows: rows);
      if (lines.isNotEmpty) {
        chosen.add((rows, lines[_random.nextInt(lines.length)]));
      }
    }
    audio.play(Cue.guideWarning);
    for (final (rows, line) in chosen) {
      markGuide(horizontal: rows, line: line);
    }
  }

  /// Puts one guide on the floor, along a row ([horizontal]) or a column at
  /// [line]. Public so a test can place one exactly.
  AlignmentGuide markGuide({required bool horizontal, required double line}) {
    final guide = AlignmentGuide(
      horizontal: horizontal,
      line: line,
      warning: warning,
      onStrike: _strike,
    );
    _floor?.add(guide);
    return guide;
  }

  /// A guide strikes: whoever is on its line is hit. Snapped, the player is
  /// either exactly on a line or a whole spacing away from it.
  void _strike(AlignmentGuide guide) {
    audio.play(Cue.guideStrike);
    final player = aimAt();
    final along = guide.horizontal ? player.y : player.x;
    if ((along - guide.line).abs() < 1) {
      context.strikePlayer();
    }
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

  @override
  void takeHit([int amount = 1]) {
    for (var i = 0; i < amount && !_defeated; i++) {
      _hitsThisSpacing++;
      if (_hitsThisSpacing < hitsPerSpacing) {
        Impact.hit(_actor);
        _actor.hit();
        audio.play(Cue.snapHit);
        continue;
      }
      _hitsThisSpacing = 0;
      final before = spacingCm!;
      _step++;
      // What the hit cost, in the dialog's own units: spacing off the grid.
      final lost = before - (spacingCm ?? 0);
      final floor = _floor;
      if (floor != null) {
        Impact.damage(
          floor,
          position - Vector2(0, size.y / 2),
          '−${lost == lost.roundToDouble() ? lost.round() : lost} cm',
        );
      }
      if (spacingCm == null) {
        _switchOff();
      } else {
        Impact.hit(_actor);
        _actor.hit();
        audio.play(Cue.gridFiner);
        _applySpacing();
      }
    }
  }

  /// Snapping off: the grid goes back to the plain floor, the player moves
  /// freely again, and every guide still waiting is cleared.
  void _switchOff() {
    _defeated = true;
    _actor.die();
    audio.play(Cue.snapOff);
    _applySpacing();
    _floor?.children.whereType<AlignmentGuide>().forEach(
      (guide) => guide.removeFromParent(),
    );
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

  final Paint _dialogPaint = Paint()..color = Palette.slide;
  final Paint _titlePaint = Paint()..color = Palette.snapToGrid;
  final Paint _edgePaint = Paint()
    ..color = Palette.snapToGridDark
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  final Paint _boxPaint = Paint()
    ..color = Palette.inkSoft
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _tickPaint = Paint()
    ..color = Palette.snapToGrid
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;

  /// A small grid dialog: a title bar, the Snap to grid box -- ticked until
  /// the very end -- and the spacing in force.
  @override
  void render(Canvas canvas) {
    final dialog = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(8));
    canvas
      ..drawRRect(dialog, _dialogPaint)
      ..drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, width, 28),
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
        ),
        _titlePaint,
      );
    SlideText.paneTitle.render(
      canvas,
      'Grid',
      Vector2(10, 14),
      anchor: Anchor.centerLeft,
    );
    final box = Rect.fromLTWH(10, 40, 16, 16);
    canvas.drawRect(box, _boxPaint);
    if (!_defeated) {
      canvas
        ..drawLine(box.centerLeft.translate(3, 0), box.bottomCenter.translate(0, -4), _tickPaint)
        ..drawLine(box.bottomCenter.translate(0, -4), box.topRight.translate(-2, 3), _tickPaint);
    }
    SlideText.dialogText.render(
      canvas,
      'Snap',
      Vector2(32, 48),
      anchor: Anchor.centerLeft,
    );
    SlideText.dialogText.render(
      canvas,
      _spacingLabel,
      Vector2(10, 80),
      anchor: Anchor.centerLeft,
    );
    canvas.drawRRect(dialog, _edgePaint);
  }
}

/// An alignment guide across the arena: a dashed warning along a row or a
/// column first, then a strike along it.
class AlignmentGuide extends PositionComponent with ParentIsA<ArenaFloor> {
  AlignmentGuide({
    required this.horizontal,
    required this.line,
    required this.warning,
    required this.onStrike,
  }) : super(priority: 4);

  /// Whether it runs along a row (true) or down a column.
  final bool horizontal;

  /// Where the row or column is, in arena units.
  final double line;

  /// Seconds of warning before it strikes.
  final double warning;

  final void Function(AlignmentGuide guide) onStrike;

  static const double strikeTime = 0.25;

  double _elapsed = 0;

  /// Whether the warning is over and the strike is showing.
  bool get hasStruck => _elapsed >= warning;

  final Paint _warnPaint = Paint()
    ..color = Palette.snapToGrid
    ..strokeWidth = 3;
  final Paint _strikePaint = Paint()
    ..color = const Color(0xFFFFB3E4)
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.round;

  @override
  void update(double dt) {
    super.update(dt);
    final before = _elapsed;
    _elapsed += dt;
    if (before < warning && _elapsed >= warning) {
      onStrike(this);
    }
    if (_elapsed >= warning + strikeTime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final size = parent.size;
    final from = horizontal ? Offset(0, line) : Offset(line, 0);
    final to = horizontal ? Offset(size.x, line) : Offset(line, size.y);
    if (hasStruck) {
      canvas.drawLine(from, to, _strikePaint);
      return;
    }
    // The dashes march along the line to draw the eye -- unless motion is
    // reduced, when they hold still.
    final shift = Motion.reduced ? 0.0 : (_elapsed * 60) % 20;
    drawDashedLine(canvas, from, to, _warnPaint, dash: 12, gap: 8, offset: shift);
  }
}
