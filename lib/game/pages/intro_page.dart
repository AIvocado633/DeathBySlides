import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../audio/game_audio.dart';
import '../components/low_resolution.dart';
import '../slide/fly_in.dart';
import '../slide/motion.dart';
import '../slide/slide_metrics.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';
import 'cutscene_page.dart';

/// The story before the deck: *the night before*.
///
/// Five short scenes, about twenty seconds, played on a first launch and at
/// the start of *The Night Before* on the title slide:
///
/// 1. 11:58 PM, a blank slide, and a presentation at 9.
/// 2. The slide fights back: Shrink-to-Fit, the Diagram Wizard and the
///    Master Template each wreck the slide in turn.
/// 3. The deck turns out to have been last saved in 2003.
/// 4. The view zooms into the slide, and takes the presenter with it.
/// 5. The title card, and the title slide.
class IntroPage extends CutscenePage {
  /// When each scene starts, in seconds.
  static const List<double> sceneStarts = [0, 4, 10.5, 14, 17.5];
  static const double totalLength = 20.5;

  /// How long presses are ignored. Kept here for the intro's own tests.
  static const double skipDelay = CutscenePage.skipDelay;

  @override
  double get length => totalLength;

  /// Which scene is showing, from 0.
  int get scene => sceneStarts.lastIndexWhere((start) => elapsed >= start);

  late final PositionComponent _editor;
  late final EditorScene _scene;

  @override
  Iterable<Cue> get cues => [
    ...super.cues,
    Cue.bulletPoint,
    Cue.shrinkToFitHit,
    Cue.diagramReflow,
    Cue.themeApplied,
    Cue.compatibilityChecker,
    Cue.drumRoll,
  ];

  @override
  Future<void> build() async {
    _editor = PositionComponent(size: slideSize);
    _scene = EditorScene(
      _editor,
      clock: '11:58 PM',
      title: 'Click to add title',
      bullets: false,
    );
    _scene.title.textRenderer = SlideText.subtitle;
    await add(_editor);
  }

  @override
  void markSeen() => unawaited(game.save.markIntroSeen());

  @override
  void plan() {
    final title = _scene.title;

    // 1. The night before.
    at(0, () => say('Tuesday, 11:58 PM. The big presentation is at 9.'));

    // 2. The slide fights back.
    at(4, () {
      say('Just a title and three bullets, then bed.');
      title
        ..text = ''
        ..textRenderer = SlideText.titleInk;
    });
    const words = 'Q3 Results';
    for (var i = 1; i <= words.length; i++) {
      at(4 + i * 0.09, () {
        title.text = words.substring(0, i);
        if (words[i - 1] != ' ') {
          game.audio.play(Cue.bulletPoint);
        }
      });
    }
    for (final (i, bullet) in _scene.bullets.indexed) {
      at(5.2 + i * 0.2, () => _editor.add(bullet..flyIn()));
    }
    at(6.2, () {
      say('Shrink-to-Fit had other ideas.');
      game.audio.play(Cue.shrinkToFitHit);
      _scene.cameo(
        this,
        'shrink_to_fit',
        Palette.shrinkToFit,
        Vector2(640, 160),
      );
      ease(title, scale: Vector2.all(0.35));
    });
    at(7.6, () {
      say('So did the Diagram Wizard.');
      game.audio.play(Cue.diagramReflow);
      _scene.cameo(
        this,
        'diagram_wizard',
        Palette.diagramWizard,
        Vector2(770, 375),
      );
      for (final bullet in _scene.bullets) {
        bullet.removeFromParent();
      }
      _editor.add(_Diagram(position: Vector2(kSlideMargin + 40, 330)));
    });
    at(9, () {
      say('And the Master Template.');
      game.audio.play(Cue.themeApplied);
      _scene.cameo(
        this,
        'master_template',
        Palette.masterTemplate,
        Vector2(420, 560),
      );
      _scene.tint(const Color(0x40C77D1A));
    });

    // 3. Saved in 2003.
    at(10.5, () {
      say('Then it turned out the deck was last saved in 2003.');
      game.audio.play(Cue.compatibilityChecker);
      _scene.presenter.hit();
      // The deck goes low-resolution; the warning itself stays readable.
      _editor.decorator.addLast(LowResolution(slideSize, factor: 3));
      add(
        LegacyDialog(
          title: 'Compatibility Mode',
          lines: const [
            'Q3 Results.sld',
            'This deck was last saved in 2003.',
            'Some features will not be available.',
          ],
        ),
      );
    });

    // 4. Into the deck.
    at(14, () {
      say('There was only one way to finish this deck.');
      game.audio.play(Cue.whoosh);
      if (Motion.reduced) {
        blackout.opacity = 1;
        return;
      }
      // Into the slide, towards the presenter.
      final towards = _scene.presenter.position;
      _editor
        ..anchor = Anchor(towards.x / kSlideWidth, towards.y / kSlideHeight)
        ..position = towards.clone()
        ..add(
          ScaleEffect.to(
            Vector2.all(3),
            EffectController(duration: 2.6, curve: Curves.easeInCubic),
          ),
        );
      blackout.add(
        OpacityEffect.to(1, EffectController(duration: 1.4, startDelay: 1.6)),
      );
    });

    // 5. The title card.
    at(17.5, () {
      hideCaption();
      blackout.opacity = 1;
      game.audio.play(Cue.drumRoll);
      const brand = 'DEATH BY ';
      final brandWidth = SlideText.titleBrand.getLineMetrics(brand).width;
      final whole =
          brandWidth + SlideText.showTitle.getLineMetrics('SLIDES').width;
      final left = (kSlideWidth - whole) / 2;
      addAll([
        TextComponent(
          text: brand,
          textRenderer: SlideText.titleBrand,
          position: Vector2(left, kSlideHeight / 2),
          anchor: Anchor.centerLeft,
          priority: 8,
        )..flyIn(),
        TextComponent(
          text: 'SLIDES',
          textRenderer: SlideText.showTitle,
          position: Vector2(left + brandWidth, kSlideHeight / 2),
          anchor: Anchor.centerLeft,
          priority: 8,
        )..flyIn(from: Vector2(110, 0)),
      ]);
    });
  }
}

/// The three bullets after the Diagram Wizard got to them: three shapes in a
/// row, joined up, saying nothing.
class _Diagram extends PositionComponent {
  _Diagram({required super.position}) : super(size: Vector2(560, 90));

  final Paint _shape = Paint()..color = Palette.diagramWizard;
  final Paint _line = Paint()
    ..color = Palette.diagramWizardDark
    ..strokeWidth = 4;

  @override
  void render(Canvas canvas) {
    const box = 120.0;
    final gap = (width - box * 3) / 2;
    for (var i = 0; i < 3; i++) {
      final left = i * (box + gap);
      if (i > 0) {
        canvas.drawLine(
          Offset(left - gap, height / 2),
          Offset(left, height / 2),
          _line,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 0, box, height),
          const Radius.circular(12),
        ),
        _shape,
      );
    }
  }
}
