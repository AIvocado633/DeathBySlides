import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../audio/game_audio.dart';
import '../combat/build_order_boss.dart' show BuildPane, BuildQueue;
import '../components/low_resolution.dart';
import '../components/shape_actor.dart';
import '../components/slide_painting.dart';
import '../slide/fly_in.dart';
import '../slide/slide_metrics.dart';
import '../theme/palette.dart';
import 'cutscene_page.dart';

/// The story between two slides: the same night, a little later each time.
///
/// Scene [after] plays once slide [after] is won, on the way into the next
/// one; scene 6 is the morning of the presentation, before the end of the
/// show. Each shows the clock moving on, the beaten feature gone, and the
/// next one turning up.
class StoryPage extends CutscenePage {
  StoryPage({required this.after})
    : assert(scenes.containsKey(after), 'No story after slide $after');

  /// The slide this scene follows.
  final int after;

  /// What each scene opens on: the time, and its first line.
  static const Map<int, ({String clock, String opening})> scenes = {
    1: (clock: '12:40 AM', opening: '12:40 AM. The title fits at last.'),
    2: (clock: '1:55 AM', opening: '1:55 AM. Bullets again. Much better.'),
    3: (clock: '3:30 AM', opening: '3:30 AM. Plain again. A bit dull, though.'),
    4: (clock: '5:10 AM', opening: '5:10 AM. The animations are gone.'),
    5: (clock: '7:45 AM', opening: '7:45 AM. Everything lines up.'),
    6: (clock: '8:59 AM', opening: '8:59 AM. The deck is done.'),
  };

  static const double sceneLength = 8.5;

  @override
  double get length => sceneLength;

  late final PositionComponent _editor;
  late final EditorScene _scene;

  @override
  Iterable<Cue> get cues => [
    ...super.cues,
    Cue.bulletPoint,
    Cue.buildStepStarted,
    Cue.themeApplied,
    Cue.buildReorder,
    Cue.snapHit,
    Cue.gridFiner,
    Cue.compatibilityChecker,
    Cue.applause,
  ];

  @override
  Future<void> build() async {
    _editor = PositionComponent(size: slideSize);
    _scene = EditorScene(
      _editor,
      clock: scenes[after]!.clock,
      bullets: after != 1 && after != 4,
      presenterAt: after == 3 ? Vector2(900, 330) : null,
    );
    await add(_editor);
  }

  @override
  void markSeen() => unawaited(game.save.markStorySeen(after));

  @override
  void plan() {
    at(0, () => say(scenes[after]!.opening));
    switch (after) {
      case 1:
        _diagramWizardArrives();
      case 2:
        _masterTemplateArrives();
      case 3:
        _buildOrderArrives();
      case 4:
        _snapToGridArrives();
      case 5:
        _legacyFormatArrives();
      default:
        _onStage();
    }
  }

  /// After Shrink-to-Fit: three bullets, and a suggestion with one button.
  void _diagramWizardArrives() {
    for (final (i, bullet) in _scene.bullets.indexed) {
      at(1.6 + i * 0.25, () {
        game.audio.play(Cue.bulletPoint);
        _editor.add(bullet..flyIn());
      });
    }
    at(3.2, () {
      say('Then the editor had a suggestion.');
      game.audio.play(Cue.buildStepStarted);
      popIn(
        this,
        EditorDialog(
          title: 'Design Ideas',
          message: 'Turn these bullets into a diagram?',
          button: 'Yes',
          position: Vector2(560, 400),
        ),
      );
    });
    at(5.2, () {
      say('There was only one button.');
      game.audio.play(Cue.diagramReflow);
      _scene.cameo(
        this,
        'diagram_wizard',
        Palette.diagramWizard,
        Vector2(820, 520),
      );
    });
  }

  /// After the Diagram Wizard: a quick look at the themes.
  void _masterTemplateArrives() {
    at(2.2, () {
      say('Just a quick look at the themes…');
      _scene.openTab('Tweak');
    });
    at(3.6, () {
      popIn(
        this,
        EditorDialog(
          title: 'Master Template',
          message: 'Apply this theme to every slide?',
          button: 'Apply to All',
          position: Vector2(560, 400),
        ),
      );
    });
    at(5.4, () {
      say('It applied to every slide.');
      game.audio.play(Cue.themeApplied);
      _scene.tint(const Color(0x40C77D1A));
      _scene.cameo(
        this,
        'master_template',
        Palette.masterTemplate,
        Vector2(700, 150),
      );
    });
  }

  /// After the Master Template: one animation, to make it pop.
  void _buildOrderArrives() {
    at(2.2, () {
      say('One animation, to make it pop.');
      game.audio.play(Cue.buildStepStarted);
      _scene.openTab('Motion');
      popIn(_editor, _Star(position: Vector2(560, 160)));
    });
    at(4.2, () {
      say('It came with sixteen friends.');
      game.audio.play(Cue.buildReorder);
      _scene.presenter.hit();
      _editor.add(
        BuildPane(
          queue: BuildQueue(BuildQueue.opening()),
          position: Vector2(1080, 150),
        )..flyIn(from: Vector2(220, 0)),
      );
    });
  }

  /// After the Build Order: a box that will not stay put.
  void _snapToGridArrives() {
    final box = _Box(position: Vector2(300, 380));
    at(0, () => _editor.add(box));
    at(2, () => say('Just a little to the left…'));
    for (final start in [2.0, 3.4]) {
      at(start, () => glide(box, Vector2(272, 380)));
      at(start + 0.7, () {
        game.audio.play(Cue.snapHit);
        glide(box, Vector2(300, 380), duration: 0.08);
      });
    }
    at(5.2, () {
      say('Snap to Grid had been on all along.');
      game.audio.play(Cue.gridFiner);
      _editor.add(_GridOverlay());
      _scene.cameo(this, 'snap_to_grid', Palette.snapToGrid, Vector2(720, 520));
    });
  }

  /// After Snap to Grid: save, and done.
  void _legacyFormatArrives() {
    at(2, () {
      say('Save, and done.');
      _scene.status('Saving…');
    });
    at(3.4, () {
      game.audio.play(Cue.compatibilityChecker);
      add(
        LegacyDialog(
          title: 'Save As',
          lines: const [
            'Q3 Results.sld',
            'This deck is in an old format.',
            'Keep it that way?',
          ],
        ),
      );
    });
    at(5.2, () {
      say('The deck had other plans.');
      _scene.presenter.hit();
      _editor.decorator.addLast(LowResolution(slideSize, factor: 3));
    });
  }

  /// The morning: on stage, at last.
  void _onStage() {
    final presenter = ShapeActor(
      actor: 'hero',
      position: Vector2(-160, 400),
      size: Vector2.all(240),
      anchor: Anchor.center,
    );
    at(0, () {
      blackout.opacity = 1;
      addAll([_Stage(), presenter..priority = 5]);
    });
    at(2.4, () {
      say('The presenter walks on stage.');
      presenter.walking = true;
      glide(presenter, Vector2(kSlideWidth / 2, 400), duration: 1.6);
    });
    at(4.2, () => presenter.walking = false);
    at(4.6, () {
      say('And the slides, for once, behave.');
      presenter.cheering = true;
      game.audio.play(Cue.applause);
    });
  }
}

/// The star an editor puts beside anything animated.
class _Star extends PositionComponent {
  _Star({required super.position})
    : super(size: Vector2.all(56), anchor: Anchor.center);

  final Paint _paint = Paint()..color = Palette.emphasisStar;

  @override
  void render(Canvas canvas) => canvas.drawPath(
    starPath(Offset(width / 2, height / 2), width / 2),
    _paint,
  );
}

/// A box the presenter keeps trying to nudge.
class _Box extends PositionComponent {
  _Box({required super.position})
    : super(size: Vector2(220, 130), anchor: Anchor.center);

  final Paint _fill = Paint()..color = Palette.brandLight;
  final Paint _edge = Paint()
    ..color = Palette.brandDark
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;

  @override
  void render(Canvas canvas) {
    final box = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(10),
    );
    canvas
      ..drawRRect(box, _fill)
      ..drawRRect(box, _edge);
  }
}

/// The grid Snap to Grid had been snapping to all along.
class _GridOverlay extends PositionComponent {
  _GridOverlay()
    : super(
        position: Vector2(0, kContentTop),
        size: Vector2(kSlideWidth, kContentBottom - kContentTop),
      );

  final Paint _line = Paint()
    ..color = const Color(0x55D14FA8)
    ..strokeWidth = 1.5;

  @override
  void render(Canvas canvas) {
    const spacing = 40.0;
    for (var x = 0.0; x <= width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), _line);
    }
    for (var y = 0.0; y <= height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(width, y), _line);
    }
  }
}

/// A stage in the dark: a spotlight, and the audience's heads.
class _Stage extends PositionComponent {
  /// Above the blackout, under the caption.
  _Stage() : super(size: slideSize, priority: 5);

  final Paint _audience = Paint()..color = const Color(0xFF1E2638);

  @override
  void render(Canvas canvas) {
    final light = Offset(kSlideWidth / 2, 430);
    canvas.drawCircle(
      light,
      260,
      Paint()
        ..shader = Gradient.radial(light, 260, const [
          Color(0x55F4B942),
          Color(0x00F4B942),
        ]),
    );
    final random = math.Random(4);
    for (var x = 40.0; x < kSlideWidth; x += 70) {
      final y = 700 + random.nextDouble() * 12;
      canvas
        ..drawCircle(Offset(x, y - 34), 22, _audience)
        ..drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 70, height: 40),
          _audience,
        );
    }
  }
}
