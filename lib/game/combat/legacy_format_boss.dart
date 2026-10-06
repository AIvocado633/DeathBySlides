import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/text.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../audio/game_audio.dart';
import '../components/arena_floor.dart';
import '../components/low_resolution.dart';
import '../components/slide_painting.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';
import 'boss.dart';
import 'build_order_boss.dart';
import 'diagram_wizard_boss.dart';
import 'health.dart';
import 'impact.dart';
import 'master_template_boss.dart';
import 'projectiles.dart';
import 'snap_to_grid_boss.dart';

/// The conversion, one stage at a time: every earlier feature, fought again
/// as the old file format saves it, oldest format first.
enum LegacyStage {
  shrinkToFit('Shrink-to-Fit', format: '97-2003', hits: 6),
  diagramWizard('Diagram Wizard', format: '2007', hits: 6),
  masterTemplate('Master Template', format: '2010', hits: 6),
  buildOrder('Build Order', format: '2013', hits: 6),
  snapToGrid('Snap to Grid', format: '2016', hits: 6),

  /// File ▸ Info ▸ Convert: the final blow.
  convert('Convert', format: '2019', hits: 4);

  const LegacyStage(this.title, {required this.format, required this.hits});

  /// The feature fought in this stage, as its heading names it.
  final String title;

  /// The format the file is stuck in while this stage stands.
  final String format;

  /// Hits this stage takes.
  final int hits;
}

/// The sixth and final boss: a deck last saved in 2003.
///
/// The final exam. It reruns the earlier fights in lower fidelity, one
/// [LegacyStage] at a time: Shrink-to-Fit throwing in eight directions only,
/// the Diagram Wizard flattened into a single picture that cannot be edited,
/// the Master Template with the themes the old format can store, a Build
/// Order that only knows After Last, and Snap to Grid's guides on a grid that
/// never gets finer.
///
/// Between stages the Compatibility Checker comes up over the arena and names
/// one of the *player's* features the old format does not support, and
/// switches it off for a while (see [PlayerFeature]).
///
/// Its health is the conversion: the readout is the format the file is stuck
/// in, and each stage beaten saves it one format forward. The last stage is
/// File ▸ Info ▸ Convert.
class LegacyFormatBoss extends Boss implements BuildStage {
  LegacyFormatBoss(super.context, {int? seed})
    : _random = math.Random(seed),
      super(
        // Covers the arena exactly, so its local space is the arena's.
        position: context.arenaSize / 2,
        size: context.arenaSize.clone(),
      );

  final math.Random _random;

  /// How long the Compatibility Checker can be read before it switches
  /// something off. Nothing is thrown at the player meanwhile.
  static const double checkerReadTime = 2.2;

  /// How long a feature stays off once the checker has switched it off.
  static const double featureOffFor = 9;

  /// The features the checker switches off, in turn.
  static const List<PlayerFeature> checkedFeatures = [
    PlayerFeature.independentAim,
    PlayerFeature.diagonalMovement,
  ];

  /// The old format's floor: a navy slide with its grid.
  static const floorLook = FloorLook(
    floor: Palette.legacyFloor,
    pattern: FloorPattern.grid,
    patternColour: Palette.legacyFloorGrid,
  );

  int _stageIndex = 0;

  /// The stage standing now, or about to once the checker has been read.
  LegacyStage get stage =>
      LegacyStage.values[math.min(_stageIndex, LegacyStage.values.length - 1)];

  /// The stage being fought, or null while the checker is being read.
  LegacyPhase? get phase => _phase;
  LegacyPhase? _phase;

  /// The Compatibility Checker, while it is up or a feature is still off.
  CompatibilityChecker? get checker => _checker;
  CompatibilityChecker? _checker;
  int _checks = 0;

  ArenaFloor? get _floor {
    final floor = parent;
    return floor is ArenaFloor ? floor : null;
  }

  @override
  int get remainingHits {
    if (_defeated) {
      return 0;
    }
    final now = _phase?.window.health.current ?? stage.hits;
    return now +
        LegacyStage.values
            .skip(_stageIndex + 1)
            .fold(0, (sum, later) => sum + later.hits);
  }

  @override
  int get totalHits =>
      LegacyStage.values.fold(0, (sum, stage) => sum + stage.hits);

  @override
  String get readout => _defeated ? 'converted' : stage.format;

  @override
  bool get isDefeated => _defeated;
  bool _defeated = false;

  @override
  Iterable<Cue> get cues => const [
    Cue.legacyHit,
    Cue.formatUpgraded,
    Cue.compatibilityChecker,
    Cue.legacyConverted,
    Cue.themeWarning,
    Cue.themeApplied,
    Cue.buildStepStarted,
    Cue.guideWarning,
    Cue.guideStrike,
  ];

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

  @override
  Future<void> onLoad() async {
    // Everything the old file holds is drawn at half the resolution. Shots,
    // the player and the checker stay sharp: they are not in the file.
    decorator.addLast(LowResolution(size));
    _begin(stage);
  }

  @override
  void onMount() {
    super.onMount();
    _floor?.look = floorLook;
  }

  /// Seconds left before a converted deck leaves the slide.
  double _closingIn = 0;
  bool _closed = false;
  static const double _closingTime = 0.45;

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
    }
  }

  /// Takes [amount] hits off the stage being fought. A hit that lands while
  /// the checker is still being read cuts the reading short, so a fight can
  /// be driven hit by hit from a test.
  @override
  void takeHit([int amount = 1]) {
    for (var i = 0; i < amount && !_defeated; i++) {
      if (_phase == null) {
        _checker?.skipReading();
      }
      _phase?.window.takeHit();
    }
  }

  void _begin(LegacyStage stage) {
    final phase = switch (stage) {
      LegacyStage.shrinkToFit => ShrinkPhase(this),
      LegacyStage.diagramWizard => PicturePhase(this),
      LegacyStage.masterTemplate => ThemePhase(this),
      LegacyStage.buildOrder => BuildPhase(this),
      LegacyStage.snapToGrid => GuidePhase(this),
      LegacyStage.convert => ConvertPhase(this),
    };
    _phase = phase;
    addAll([
      phase.window,
      phase,
      WordArtHeading(stage.title, position: Vector2(size.x / 2, size.y * 0.6)),
    ]);
  }

  /// A window for [stage], wired to this boss.
  LegacyWindow _window({
    required LegacyStage stage,
    required String title,
    required Vector2 position,
    required Vector2 size,
    required void Function(Canvas canvas, Rect body) paintBody,
  }) => LegacyWindow(
    title: title,
    hits: stage.hits,
    position: position,
    size: size,
    paintBody: paintBody,
    onHit: () => audio.play(Cue.legacyHit),
    onBroken: _onStageBroken,
  );

  /// A stage beaten: the file is saved one format forward, and the checker
  /// comes up before the next.
  void _onStageBroken() {
    final finished = _phase;
    if (finished == null) {
      return;
    }
    _phase = null;
    finished
      ..end()
      ..removeFromParent();
    _stageIndex++;
    if (_stageIndex >= LegacyStage.values.length) {
      _convert();
      return;
    }
    audio.play(Cue.formatUpgraded);
    final floor = _floor;
    if (floor != null) {
      // What the stage cost it, in its own units: a format forward.
      Impact.damage(
        floor,
        finished.window.position - Vector2(0, finished.window.size.y / 2),
        'Saved as ${stage.format}',
      );
    }
    _check();
  }

  /// The Compatibility Checker names one of the player's features, and once
  /// it has been read, switches it off and lets the next stage begin.
  void _check() {
    _checker?.finish();
    final feature = checkedFeatures[_checks++ % checkedFeatures.length];
    late final CompatibilityChecker checker;
    checker = CompatibilityChecker(
      feature: feature,
      arenaSize: size,
      readFor: checkerReadTime,
      offFor: featureOffFor,
      onRead: () {
        context.setPlayerFeature(feature, on: false);
        _begin(stage);
      },
      onRestore: () {
        context.setPlayerFeature(feature, on: true);
        if (identical(_checker, checker)) {
          _checker = null;
        }
      },
    );
    _checker = checker;
    audio.play(Cue.compatibilityChecker);
    final floor = _floor;
    if (floor != null) {
      floor.add(checker);
    } else {
      // Off the board there is nobody to read it.
      checker.skipReading();
    }
  }

  /// File ▸ Info ▸ Convert: everything the player lost comes back, and the
  /// slide is saved in a format from this century.
  void _convert() {
    _defeated = true;
    _closingIn = _closingTime;
    _checker?.finish();
    _checker = null;
    audio.play(Cue.legacyConverted);
    context.setPlayerShotRules(ShotRules.standard);
    final floor = _floor;
    if (floor != null) {
      floor.look = FloorLook.standard;
      Impact.damage(floor, Vector2(size.x / 2, 110), 'Converted');
    }
  }
}

/// One stage of the conversion: the degraded feature's window, and its
/// attack. A child of the boss, so it pauses with the fight and is gone the
/// moment its window breaks.
abstract class LegacyPhase extends Component {
  LegacyPhase(this.boss);

  final LegacyFormatBoss boss;

  /// What the player shoots at in this stage: always a single window.
  LegacyWindow get window;

  Vector2 get arena => boss.size;
  ArenaFloor? get floor => boss._floor;

  /// Adds a shot to the board.
  void shoot(EnemyShot shot) => boss.parent?.add(shot);

  /// Tidies away whatever the stage left on the board.
  void end() {}
}

/// Shrink-to-Fit, saved down: it still shrinks, but its ladder has six sizes
/// and it can only throw in eight directions.
class ShrinkPhase extends LegacyPhase {
  ShrinkPhase(super.boss);

  /// The point sizes it steps down, one per hit.
  static const List<int> ladder = [54, 44, 36, 28, 18, 8];

  static const double fireInterval = 1.5;
  static const double _patrolSpeed = 0.7;
  static const double _patrolReach = 160;

  @override
  late final LegacyWindow window = boss._window(
    stage: LegacyStage.shrinkToFit,
    title: 'Shrink-to-Fit',
    position: Vector2(arena.x / 2, 92),
    size: Vector2(200, 128),
    paintBody: _paintBody,
  );

  int get pointSize =>
      ladder[math.min(
        ladder.length - window.health.current,
        ladder.length - 1,
      )];

  double _patrol = 0;
  double _sinceShot = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _patrol += dt * _patrolSpeed;
    window.position.x = arena.x / 2 + math.sin(_patrol) * _patrolReach;
    _sinceShot += dt;
    if (_sinceShot >= fireInterval) {
      _sinceShot = 0;
      final toTarget = boss.aimAt() - window.position;
      if (!toTarget.isZero()) {
        shoot(
          ResizeHandle(
            position: window.position.clone(),
            velocity: eightWay(toTarget)..scale(ResizeHandle.speed),
          ),
        );
      }
    }
  }

  /// [direction] rounded to the nearest of eight ways, unit length: all the
  /// aim the old format can store.
  static Vector2 eightWay(Vector2 direction) {
    const step = math.pi / 4;
    final angle = (math.atan2(direction.y, direction.x) / step).round() * step;
    return Vector2(math.cos(angle), math.sin(angle));
  }

  final Map<int, TextPaint> _renderers = {};

  void _paintBody(Canvas canvas, Rect body) {
    final points = pointSize;
    final renderer = _renderers.putIfAbsent(
      points,
      () => TextPaint(
        style: TextStyle(
          fontSize: 10 + points * 0.5,
          fontWeight: FontWeight.w700,
          color: Palette.shrinkToFit,
          fontFamily: kFontFamily,
          fontFamilyFallback: kFontStack,
        ),
      ),
    );
    renderer.render(
      canvas,
      '$points pt',
      Vector2(body.center.dx, body.center.dy),
      anchor: Anchor.center,
    );
  }
}

/// The Diagram Wizard did not exist in 2003, so it arrives converted to a
/// picture: one flat target that cannot be edited, and never rearranges.
class PicturePhase extends LegacyPhase {
  PicturePhase(super.boss);

  static const double fireInterval = 1.2;

  @override
  late final LegacyWindow window = boss._window(
    stage: LegacyStage.diagramWizard,
    title: 'Picture 1',
    position: Vector2(arena.x / 2, 112),
    size: Vector2(300, 180),
    paintBody: _paintBody,
  );

  double _sinceShot = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _sinceShot += dt;
    if (_sinceShot >= fireInterval) {
      _sinceShot = 0;
      final toTarget = boss.aimAt() - window.position;
      if (!toTarget.isZero()) {
        shoot(
          ConnectorArrow(
            position: window.position.clone(),
            velocity: toTarget.normalized()..scale(ConnectorArrow.speed),
          ),
        );
      }
    }
  }

  final Paint _node = Paint()..color = Palette.diagramWizard;
  final Paint _line = Paint()
    ..color = Palette.diagramWizardDark
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;

  /// The six shapes, as the cycle the Diagram Wizard opens with, flattened.
  void _paintBody(Canvas canvas, Rect body) {
    final places = DiagramWizardBoss.positionsFor(
      DiagramLayout.cycle,
      6,
      Vector2(body.width, body.height),
    ).map((place) => body.topLeft + place.toOffset()).toList();
    for (var i = 0; i < places.length; i++) {
      canvas.drawLine(places[i], places[(i + 1) % places.length], _line);
    }
    for (final place in places) {
      canvas.drawRect(
        Rect.fromCenter(center: place, width: 34, height: 34),
        _node,
      );
    }
  }
}

/// The Master Template, saved down: one master, no layouts, and only the
/// themes the old format can store -- nothing curves in 2003.
class ThemePhase extends LegacyPhase {
  ThemePhase(super.boss);

  /// The themes it cycles through. Sleek's curves are not supported.
  static const List<SlideTheme> themes = [
    SlideTheme.plain,
    SlideTheme.rebound,
    SlideTheme.chunky,
  ];

  static const double themeInterval = 6;
  static const double fireInterval = 1.3;

  @override
  late final LegacyWindow window = boss._window(
    stage: LegacyStage.masterTemplate,
    title: 'Master Template',
    position: Vector2(arena.x / 2, 96),
    size: Vector2(230, 132),
    paintBody: _paintBody,
  );

  SlideTheme get theme => themes[_themeIndex];
  int _themeIndex = 0;

  SlideTheme get _nextTheme => themes[(_themeIndex + 1) % themes.length];

  /// The warning on screen, while one is.
  ThemeWarning? get warning => _warning;
  ThemeWarning? _warning;

  double _sinceTheme = 0;
  double _sinceShot = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _sinceTheme += dt;
    final floor = this.floor;
    if (_warning == null &&
        floor != null &&
        _sinceTheme >= themeInterval - MasterTemplateBoss.warningDuration) {
      boss.audio.play(Cue.themeWarning);
      floor.add(
        _warning = ThemeWarning(
          theme: _nextTheme,
          duration: MasterTemplateBoss.warningDuration,
          width: floor.size.x,
        ),
      );
    }
    if (_sinceTheme >= themeInterval) {
      _sinceTheme = 0;
      _themeIndex = (_themeIndex + 1) % themes.length;
      _apply(theme);
      boss.audio.play(Cue.themeApplied);
    }
    _sinceShot += dt;
    if (_sinceShot >= fireInterval) {
      _sinceShot = 0;
      final toTarget = boss.aimAt() - window.position;
      if (!toTarget.isZero()) {
        shoot(
          SwatchShot(
            position: window.position.clone(),
            velocity: toTarget.normalized()..scale(SwatchShot.speed),
            colour: theme.accent,
          )..applyRules(theme.enemy),
        );
      }
    }
  }

  /// The whole slide changes at once, as on the Master Template's own slide,
  /// except that Plain keeps the old format's floor.
  void _apply(SlideTheme theme) {
    _warning?.removeFromParent();
    _warning = null;
    final floor = this.floor;
    theme.applyTo(floor, boss.context);
    if (theme == SlideTheme.plain) {
      floor?.look = LegacyFormatBoss.floorLook;
    }
  }

  /// Back to Plain for everyone, before the next stage.
  @override
  void end() => _apply(SlideTheme.plain);

  final Paint _rule = Paint()..color = const Color(0xFFC0C0C0);

  void _paintBody(Canvas canvas, Rect body) {
    final accent = Paint()..color = theme.accent;
    canvas.drawRect(
      Rect.fromLTWH(body.left + 12, body.top + 12, body.width * 0.55, 12),
      accent,
    );
    for (final (i, fraction) in [0.8, 0.6, 0.7].indexed) {
      canvas.drawRect(
        Rect.fromLTWH(
          body.left + 12,
          body.top + 36 + i * 16,
          (body.width - 24) * fraction,
          6,
        ),
        _rule,
      );
    }
    SlideText.legacyText.render(
      canvas,
      theme.label,
      Vector2(body.right - 10, body.bottom - 8),
      anchor: Anchor.bottomRight,
    );
  }
}

/// The Build Order, saved down: four steps, every one After Last, and none
/// of the effects that curve.
class BuildPhase extends LegacyPhase {
  BuildPhase(super.boss);

  /// The steps it plays. The old format has no On Click and no With Last.
  static List<BuildStep> steps() => const [
    BuildStep(1, BuildEffect.flyIn, Trigger.afterLast),
    BuildStep(2, BuildEffect.pulse, Trigger.afterLast),
    BuildStep(3, BuildEffect.wipe, Trigger.afterLast),
    BuildStep(4, BuildEffect.bounce, Trigger.afterLast),
  ];

  /// The queue, and the rules for when each step plays.
  final BuildQueue queue = BuildQueue(steps(), gap: 0.8);

  @override
  late final LegacyWindow window = boss._window(
    stage: LegacyStage.buildOrder,
    title: 'Build Order',
    position: Vector2(arena.x / 2, 108),
    size: Vector2(214, 186),
    paintBody: _paintBody,
  );

  @override
  void update(double dt) {
    super.update(dt);
    for (final step in queue.update(dt)) {
      boss.audio.play(Cue.buildStepStarted);
      add(BuildAttack.of(step.effect, stage: boss, random: boss._random));
    }
  }

  void _paintBody(Canvas canvas, Rect body) {
    final steps = queue.steps;
    for (var row = 0; row < steps.length; row++) {
      final index = (queue.cursor + row) % steps.length;
      final step = steps[index];
      final top = body.top + 4 + row * 34;
      SlideText.legacyTextBold.render(
        canvas,
        '${index + 1}  ${step.effect.label}',
        Vector2(body.left + 8, top),
      );
      SlideText.legacyText.render(
        canvas,
        step.trigger.label,
        Vector2(body.left + 26, top + 16),
      );
    }
  }
}

/// Snap to Grid, saved down: its guides still strike, but the grid has one
/// spacing and nobody snaps to it.
class GuidePhase extends LegacyPhase {
  GuidePhase(super.boss);

  /// Seconds between volleys of guides.
  static const double volleyInterval = 2.6;

  /// How close to a guide's line the player has to be for its strike to
  /// land. Nobody snaps in this format, so the line has some width.
  static const double strikeReach = 30;

  static const double _roamSpeed = 70;

  @override
  late final LegacyWindow window = boss._window(
    stage: LegacyStage.snapToGrid,
    title: 'Grid',
    position: Vector2(arena.x / 2, 84),
    size: Vector2(170, 104),
    paintBody: _paintBody,
  );

  late final Vector2 _intended = window.position.clone();
  final Vector2 _roam = Vector2(1, 0.6)..scale(_roamSpeed);
  double _sinceVolley = 0;

  @override
  void update(double dt) {
    super.update(dt);
    final floor = this.floor;
    if (floor == null) {
      return;
    }
    _wander(floor, dt);
    _sinceVolley += dt;
    if (_sinceVolley >= volleyInterval) {
      _sinceVolley = 0;
      _markGuides(floor);
    }
  }

  /// Roams the upper arena, hopping from one grid crossing to the next.
  void _wander(ArenaFloor floor, double dt) {
    _intended.add(_roam * dt);
    final half = window.size / 2;
    final bottom = arena.y * 0.45;
    if (_intended.x < half.x || _intended.x > arena.x - half.x) {
      _roam.x = -_roam.x;
    }
    if (_intended.y < half.y || _intended.y > bottom) {
      _roam.y = -_roam.y;
    }
    _intended
      ..x = _intended.x.clamp(half.x, arena.x - half.x)
      ..y = _intended.y.clamp(half.y, bottom);
    window.position.setFrom(floor.snapToGrid(_intended, window.size));
  }

  /// The grid line nearest the player along one axis, and one more at random.
  void _markGuides(ArenaFloor floor) {
    final player = boss.aimAt();
    final ownRow = boss._random.nextBool();
    final along = ownRow ? player.y : player.x;
    final own = floor.gridLines(rows: ownRow);
    final chosen = <(bool, double)>{
      (
        ownRow,
        own.isEmpty
            ? along
            : own.reduce(
                (a, b) => (a - along).abs() <= (b - along).abs() ? a : b,
              ),
      ),
    };
    final other = floor.gridLines(rows: !ownRow);
    if (other.isNotEmpty) {
      chosen.add((!ownRow, other[boss._random.nextInt(other.length)]));
    }
    boss.audio.play(Cue.guideWarning);
    for (final (rows, line) in chosen) {
      markGuide(horizontal: rows, line: line);
    }
  }

  /// Puts one guide on the floor. Public so a test can place one exactly.
  AlignmentGuide markGuide({required bool horizontal, required double line}) {
    final guide = AlignmentGuide(
      horizontal: horizontal,
      line: line,
      warning: SnapToGridBoss.warning,
      onStrike: _strike,
    );
    _guides.add(guide);
    floor?.add(guide);
    return guide;
  }

  /// Every guide it has marked, including any not on the board yet.
  final List<AlignmentGuide> _guides = [];

  void _strike(AlignmentGuide guide) {
    boss.audio.play(Cue.guideStrike);
    final player = boss.aimAt();
    final along = guide.horizontal ? player.y : player.x;
    if ((along - guide.line).abs() < strikeReach) {
      boss.context.strikePlayer();
    }
  }

  /// No guide outlives its stage.
  @override
  void end() {
    for (final guide in _guides) {
      guide.removeFromParent();
    }
  }

  final Paint _box = Paint()
    ..color = Palette.legacyInk
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  /// Snap is unticked: the grid is only there to strike along.
  void _paintBody(Canvas canvas, Rect body) {
    final box = Rect.fromLTWH(body.left + 8, body.top + 8, 14, 14);
    canvas.drawRect(box, _box);
    SlideText.legacyText.render(
      canvas,
      'Snap',
      Vector2(box.right + 8, box.center.dy),
      anchor: Anchor.centerLeft,
    );
    SlideText.legacyText.render(
      canvas,
      'Spacing 1 cm',
      Vector2(body.left + 8, body.bottom - 8),
      anchor: Anchor.bottomLeft,
    );
  }
}

/// File ▸ Info ▸ Convert. It throws rings of resize handles while it holds
/// out, and its last hit converts the deck.
class ConvertPhase extends LegacyPhase {
  ConvertPhase(super.boss);

  static const double fireInterval = 1.6;
  static const int ringSize = 8;

  @override
  late final LegacyWindow window = boss._window(
    stage: LegacyStage.convert,
    title: 'File · Info',
    position: Vector2(arena.x / 2, 100),
    size: Vector2(260, 150),
    paintBody: _paintBody,
  );

  double _sinceShot = 0;
  int _rings = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _sinceShot += dt;
    if (_sinceShot >= fireInterval) {
      _sinceShot = 0;
      // Every other ring turns by half a gap, so standing still never works
      // twice.
      final turn = (_rings++).isEven ? 0.0 : math.pi / ringSize;
      for (var i = 0; i < ringSize; i++) {
        final angle = turn + i * 2 * math.pi / ringSize;
        shoot(
          ResizeHandle(
            position: window.position.clone(),
            velocity: Vector2(math.cos(angle), math.sin(angle))
              ..scale(ResizeHandle.speed),
          ),
        );
      }
    }
  }

  final Paint _button = Paint()..color = Palette.legacyFace;
  final Paint _buttonEdge = Paint()
    ..color = Palette.legacyShadow
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  void _paintBody(Canvas canvas, Rect body) {
    SlideText.legacyTextBold.render(
      canvas,
      'Compatibility Mode',
      Vector2(body.left + 10, body.top + 8),
    );
    SlideText.legacyText.render(
      canvas,
      'Some features are switched off.',
      Vector2(body.left + 10, body.top + 28),
    );
    final button = Rect.fromLTWH(body.left + 10, body.bottom - 44, 110, 34);
    canvas
      ..drawRect(button, _button)
      ..drawRect(button, _buttonEdge);
    SlideText.legacyTextBold.render(
      canvas,
      'Convert',
      Vector2(button.center.dx, button.center.dy),
      anchor: Anchor.center,
    );
  }
}

/// Draws a 2003-era window frame filling [size] -- grey face, a title bar
/// fading from navy to pale blue, a close box -- and returns its body.
Rect paintLegacyWindow(Canvas canvas, Vector2 size, String title) {
  const titleHeight = 24.0;
  final outer = size.toRect();
  final bar = Rect.fromLTWH(3, 3, size.x - 6, titleHeight);
  final close = Rect.fromLTWH(bar.right - 20, bar.top + 4, 16, 16);
  canvas
    ..drawRect(outer, _legacyFace)
    ..drawRect(
      bar,
      Paint()
        ..shader = ui.Gradient.linear(bar.centerLeft, bar.centerRight, const [
          Palette.legacyTitle,
          Palette.legacyTitleFade,
        ]),
    )
    ..drawRect(close, _legacyFace)
    ..drawLine(
      close.topLeft.translate(4, 4),
      close.bottomRight.translate(-4, -4),
      _legacyInkLine,
    )
    ..drawLine(
      close.topRight.translate(-4, 4),
      close.bottomLeft.translate(4, -4),
      _legacyInkLine,
    );
  SlideText.legacyTitle.render(
    canvas,
    title,
    Vector2(bar.left + 6, bar.center.dy),
    anchor: Anchor.centerLeft,
  );
  final body = Rect.fromLTRB(3, titleHeight + 6, size.x - 3, size.y - 3);
  canvas
    ..drawRect(body, _legacyBody)
    ..drawRect(outer.deflate(0.75), _legacyEdge);
  return body;
}

final Paint _legacyFace = Paint()..color = Palette.legacyFace;
final Paint _legacyBody = Paint()..color = Palette.legacyWindow;
final Paint _legacyEdge = Paint()
  ..color = Palette.legacyShadow
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.5;
final Paint _legacyInkLine = Paint()
  ..color = Palette.legacyInk
  ..strokeWidth = 2;

/// What the player shoots at in a stage: the degraded feature, in a 2003-era
/// window.
class LegacyWindow extends PositionComponent
    with CollisionCallbacks, BulletTarget {
  LegacyWindow({
    required this.title,
    required int hits,
    required super.position,
    required super.size,
    required this.paintBody,
    required this.onHit,
    required this.onBroken,
  }) : health = Health(max: hits),
       super(anchor: Anchor.center, children: [RectangleHitbox()]);

  final String title;
  final Health health;

  /// Draws what is in the window, inside its body.
  final void Function(Canvas canvas, Rect body) paintBody;

  final void Function() onHit;
  final void Function() onBroken;

  bool get isBroken => _broken;
  bool _broken = false;

  @override
  bool get isTargetable => !_broken;

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is! BulletPoint || _broken) {
      return;
    }
    other.removeFromParent();
    takeHit(other.damage);
  }

  void takeHit([int amount = 1]) {
    if (_broken) {
      return;
    }
    health.damage(amount);
    if (!health.isDead) {
      Impact.hit(this);
      onHit();
      return;
    }
    // No squash on the breaking hit: the window is about to shrink away, and
    // the two would fight over its scale.
    _broken = true;
    onBroken();
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.3, curve: Curves.easeInBack),
        onComplete: removeFromParent,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final body = paintLegacyWindow(canvas, size, title);
    canvas
      ..save()
      ..clipRect(body);
    paintBody(canvas, body);
    canvas.restore();
  }
}

/// The stage's name across the arena, WordArt-style -- a gradient fill and a
/// heavy drop shadow -- for a moment as the stage begins.
class WordArtHeading extends TextComponent {
  WordArtHeading(String text, {required super.position})
    : super(
        text: text,
        anchor: Anchor.center,
        angle: -0.06,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            fontFamily: kFontFamily,
            fontFamilyFallback: kFontStack,
            foreground: Paint()
              ..shader = ui.Gradient.linear(
                Offset.zero,
                const Offset(0, 60),
                const [Color(0xFFFFE14D), Color(0xFFFF8A1F), Color(0xFFD9262B)],
                const [0.15, 0.5, 0.9],
              ),
            shadows: const [
              Shadow(offset: Offset(4, 4), color: Color(0xFF202020)),
            ],
          ),
        ),
      );

  /// How long it stays up.
  static const double showFor = 1.6;

  double _shown = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _shown += dt;
    if (_shown >= showFor) {
      removeFromParent();
    }
  }
}

/// The Compatibility Checker: it comes up over the arena, names a feature of
/// the player's the old format does not support, and once it has been read,
/// switches that feature off for a while. Until it is back, a note in the
/// corner counts down.
class CompatibilityChecker extends PositionComponent {
  CompatibilityChecker({
    required this.feature,
    required Vector2 arenaSize,
    required this.readFor,
    required this.offFor,
    required this.onRead,
    required this.onRestore,
  }) : _arena = arenaSize.clone(),
       super(priority: 6) {
    _layout();
  }

  final PlayerFeature feature;
  final double readFor;
  final double offFor;

  /// Called once the dialog has been up for [readFor] seconds: the feature
  /// goes off now.
  final void Function() onRead;

  /// Called once the feature has been off for [offFor] seconds, or sooner if
  /// the checker is finished early.
  final void Function() onRestore;

  final Vector2 _arena;
  double _elapsed = 0;
  bool _read = false;
  bool _restored = false;

  /// Whether the dialog is still up, before anything has been switched off.
  bool get isReading => !_read;

  /// Whether [feature] is off now.
  bool get isFeatureOff => _read && !_restored;

  /// Seconds until the feature comes back, once it is off.
  double get secondsLeft =>
      _read ? math.max(0, readFor + offFor - _elapsed) : offFor;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (!_read && _elapsed >= readFor) {
      _switchOff();
    }
    if (_read && _elapsed >= readFor + offFor) {
      finish();
    }
  }

  /// Ends the reading now: the feature goes off at once.
  void skipReading() {
    if (_read) {
      return;
    }
    _elapsed = readFor;
    _switchOff();
  }

  void _switchOff() {
    _read = true;
    onRead();
    _layout();
  }

  /// Gives the feature back, if it was taken, and closes the checker.
  void finish() {
    if (_read && !_restored) {
      _restored = true;
      onRestore();
    }
    removeFromParent();
  }

  void _layout() {
    if (_read) {
      size = Vector2(320, 34);
      position = Vector2(10, _arena.y - size.y - 10);
    } else {
      size = Vector2(430, 150);
      position = (_arena - size) / 2;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_read) {
      _renderNote(canvas);
      return;
    }
    final body = paintLegacyWindow(canvas, size, 'Compatibility Checker');
    final left = body.left + 14;
    SlideText.legacyText.render(
      canvas,
      'This format does not support:',
      Vector2(left, body.top + 12),
    );
    SlideText.legacyTextBold.render(
      canvas,
      '•  ${feature.label}',
      Vector2(left + 8, body.top + 40),
    );
    SlideText.legacyText.render(
      canvas,
      'It will be switched off for ${offFor.round()} seconds.',
      Vector2(left, body.top + 72),
    );
  }

  void _renderNote(Canvas canvas) {
    canvas
      ..drawRect(size.toRect(), _legacyFace)
      ..drawRect(size.toRect().deflate(0.75), _legacyEdge);
    drawDashedLine(
      canvas,
      Offset(8, size.y - 5),
      Offset(8 + (size.x - 16) * secondsLeft / offFor, size.y - 5),
      _legacyInkLine,
      dash: 4,
      gap: 3,
    );
    SlideText.legacyText.render(
      canvas,
      '${feature.label}: off, ${secondsLeft.ceil()} s',
      Vector2(10, size.y / 2 - 2),
      anchor: Anchor.centerLeft,
    );
  }
}
