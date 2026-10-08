import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';

import '../audio/game_audio.dart';
import '../combat/legacy_format_boss.dart' show paintLegacyWindow;
import '../components/chip_button.dart';
import '../components/low_resolution.dart';
import '../components/placeholder_frame.dart';
import '../components/shape_actor.dart';
import '../components/status_bar.dart';
import '../components/toolbar.dart';
import '../input/menu_input.dart';
import '../slide/fly_in.dart';
import '../slide/focusable.dart';
import '../slide/motion.dart';
import '../slide/slide_metrics.dart';
import '../slide/slide_page.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';

/// The story before the deck: *the night before*.
///
/// Five short scenes, about twenty seconds, played on a first launch and
/// whenever the title slide's *The Night Before* is chosen:
///
/// 1. 11:58 PM, a blank slide, and a presentation at 9.
/// 2. The slide fights back: Shrink-to-Fit, the Diagram Wizard and the
///    Master Template each wreck the slide in turn.
/// 3. The deck turns out to have been last saved in 2003.
/// 4. The view zooms into the slide, and takes the presenter with it.
/// 5. The title card, and the title slide.
///
/// Every scene is a list of beats on one timeline. With [Motion.reduced] the
/// beats still come on time, but nothing moves: each one simply shows where
/// it ends. A *Skip* chip, or any tap, key or button after [skipDelay], ends
/// it at once.
class IntroPage extends SlidePage with TapCallbacks {
  /// When each scene starts, in seconds, and when the intro ends.
  static const List<double> sceneStarts = [0, 4, 10.5, 14, 17.5];
  static const double length = 20.5;

  /// How long presses are ignored, so the press that launched the game, or
  /// chose *The Night Before*, does not skip it straight away.
  static const double skipDelay = 1;

  /// Which scene is showing, from 0.
  int get scene => sceneStarts.lastIndexWhere((start) => _elapsed >= start);

  /// Seconds since the intro started.
  double get elapsed => _elapsed;
  double _elapsed = 0;

  bool _finished = false;

  /// The narration under each scene.
  String get caption => _caption.text;

  final List<({double at, void Function() run})> _beats = [];
  int _nextBeat = 0;

  late final PositionComponent _editor;
  late final ShapeActor _presenter;
  late final TextComponent _title;
  late final List<TextComponent> _bullets;
  late final _Caption _caption;
  late final RectangleComponent _blackout;
  late final ChipButton _skip;

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
  Future<void> onLoad() async {
    _editor = PositionComponent(size: slideSize);
    _blackout = RectangleComponent(
      size: slideSize,
      paint: Paint()..color = Palette.showBlack,
      priority: 5,
    )..opacity = 0;
    _caption = _Caption(priority: 6);
    _skip = ChipButton(
      label: 'Skip',
      position: Vector2(kSlideWidth - kSlideMargin, 92),
      anchor: Anchor.centerRight,
      width: 120,
      height: 44,
      onSelected: finish,
    )..priority = 7;

    _buildEditor();
    await addAll([_editor, _blackout, _caption, _skip]);
    _plan();
    _beats.sort((a, b) => a.at.compareTo(b.at));
    // The first scene is there from the first frame.
    _runDueBeats();
  }

  /// Scene 1's editor: an empty slide, late at night.
  void _buildEditor() {
    _presenter = ShapeActor(
      actor: 'hero',
      position: Vector2(1000, 330),
      size: Vector2.all(240),
      anchor: Anchor.center,
    );
    _title = TextComponent(
      text: 'Click to add title',
      textRenderer: SlideText.subtitle,
      position: Vector2(kSlideMargin + 28, 160),
      anchor: Anchor.centerLeft,
    );
    _bullets = [
      for (final (i, line) in ['Revenue', 'Costs', 'Hope'].indexed)
        TextComponent(
          text: '•  $line',
          textRenderer: SlideText.bullet,
          position: Vector2(kSlideMargin + 40, 300.0 + i * 64),
          anchor: Anchor.centerLeft,
        ),
    ];
    _editor.addAll([
      Toolbar(activeTab: 'Edit'),
      StatusBar(slideLabel: 'Slide 1 of 1', detailLabel: 'Autosaved 11:58 PM'),
      PlaceholderFrame(
        position: Vector2(kSlideMargin, 100),
        size: Vector2(700, 120),
      ),
      PlaceholderFrame(
        position: Vector2(kSlideMargin, 250),
        size: Vector2(700, 270),
      ),
      _title,
      _presenter,
    ]);
  }

  /// Every beat of every scene, on one timeline.
  void _plan() {
    // 1. The night before.
    _at(0, () => _say('Tuesday, 11:58 PM. The big presentation is at 9.'));

    // 2. The slide fights back.
    _at(4, () {
      _say('Just a title and three bullets, then bed.');
      _title
        ..text = ''
        ..textRenderer = SlideText.titleInk;
    });
    const words = 'Q3 Results';
    for (var i = 1; i <= words.length; i++) {
      _at(4 + i * 0.09, () {
        _title.text = words.substring(0, i);
        if (words[i - 1] != ' ') {
          game.audio.play(Cue.bulletPoint);
        }
      });
    }
    for (final (i, bullet) in _bullets.indexed) {
      _at(5.2 + i * 0.2, () => _editor.add(bullet..flyIn()));
    }
    _at(6.2, () {
      _say('Shrink-to-Fit had other ideas.');
      _cameo(
        'shrink_to_fit',
        Palette.shrinkToFit,
        Vector2(640, 160),
        Cue.shrinkToFitHit,
      );
      _ease(_title, scale: Vector2.all(0.35));
    });
    _at(7.6, () {
      _say('So did the Diagram Wizard.');
      _cameo(
        'diagram_wizard',
        Palette.diagramWizard,
        Vector2(770, 375),
        Cue.diagramReflow,
      );
      for (final bullet in _bullets) {
        bullet.removeFromParent();
      }
      _editor.add(_Diagram(position: Vector2(kSlideMargin + 40, 330)));
    });
    _at(9, () {
      _say('And the Master Template.');
      _cameo(
        'master_template',
        Palette.masterTemplate,
        Vector2(420, 560),
        Cue.themeApplied,
      );
      _editor.add(
        RectangleComponent(
          position: Vector2(0, kContentTop),
          size: Vector2(kSlideWidth, kContentBottom - kContentTop),
          paint: Paint()..color = const Color(0x40C77D1A),
        ),
      );
    });

    // 3. Saved in 2003.
    _at(10.5, () {
      _say('Then it turned out the deck was last saved in 2003.');
      game.audio.play(Cue.compatibilityChecker);
      _presenter.hit();
      // The deck goes low-resolution; the warning itself stays readable.
      _editor.decorator.addLast(LowResolution(slideSize, factor: 3));
      add(_LegacyDialog());
    });

    // 4. Into the deck.
    _at(14, () {
      _say('There was only one way to finish this deck.');
      game.audio.play(Cue.whoosh);
      if (Motion.reduced) {
        _blackout.opacity = 1;
        return;
      }
      // Into the slide, towards the presenter.
      final towards = _presenter.position;
      _editor
        ..anchor = Anchor(towards.x / kSlideWidth, towards.y / kSlideHeight)
        ..position = towards.clone()
        ..add(
          ScaleEffect.to(
            Vector2.all(3),
            EffectController(duration: 2.6, curve: Curves.easeInCubic),
          ),
        );
      _blackout.add(
        OpacityEffect.to(1, EffectController(duration: 1.4, startDelay: 1.6)),
      );
    });

    // 5. The title card.
    _at(17.5, () {
      _caption.hide();
      _blackout.opacity = 1;
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

    _at(length, finish);
  }

  void _at(double at, void Function() run) => _beats.add((at: at, run: run));

  void _say(String line) => _caption.show(line);

  /// A feature turning up for a second to wreck the slide: it pops in by the
  /// damage, and the presenter flinches.
  void _cameo(String actor, Color tint, Vector2 at, Cue cue) {
    game.audio.play(cue);
    _presenter.hit();
    final cameo = ShapeActor(
      actor: actor,
      tint: tint,
      position: at,
      size: Vector2.all(130),
      anchor: Anchor.center,
    );
    _editor.add(cameo);
    cameo.scale = Vector2.zero();
    _ease(cameo, scale: Vector2.all(1));
  }

  /// Eases [component] to [scale], or puts it there with Reduce Motion.
  void _ease(PositionComponent component, {required Vector2 scale}) {
    if (Motion.reduced) {
      component.scale = scale;
      return;
    }
    component.add(
      ScaleEffect.to(
        scale,
        EffectController(duration: 0.4, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) {
      return;
    }
    _elapsed += dt;
    _runDueBeats();
  }

  /// Runs every beat whose time has come, in order.
  void _runDueBeats() {
    while (_nextBeat < _beats.length && _beats[_nextBeat].at <= _elapsed) {
      _beats[_nextBeat++].run();
      if (_finished) {
        return;
      }
    }
  }

  /// Ends the intro: it is marked seen, and the title slide underneath takes
  /// over.
  void finish() {
    if (_finished) {
      return;
    }
    _finished = true;
    unawaited(game.save.markIntroSeen());
    game.router.pop();
  }

  /// Any press skips, once the press that opened the intro is out of the way.
  void _skipByPress() {
    if (_elapsed >= skipDelay) {
      finish();
    }
  }

  @override
  void onAnyPress() => _skipByPress();

  /// Keys and buttons arrive here too, as menu actions; arrows only move
  /// focus to the Skip chip.
  @override
  void onMenuAction(MenuAction action) {
    if (action.isDirection) {
      super.onMenuAction(action);
      return;
    }
    _skipByPress();
  }

  @override
  void onTapUp(TapUpEvent event) => _skipByPress();

  @override
  List<Focusable> get focusables => [_skip];
}

/// The narration strip along the bottom of the slide.
class _Caption extends PositionComponent {
  _Caption({super.priority})
    : super(
        position: Vector2(kSlideWidth / 2, 630),
        size: Vector2(980, 56),
        anchor: Anchor.center,
      );

  late final TextComponent _text = TextComponent(
    textRenderer: SlideText.showBody,
    position: size / 2,
    anchor: Anchor.center,
  );

  bool _visible = false;

  String get text => _text.text;

  final Paint _paint = Paint()..color = const Color(0xE60B0F18);

  @override
  Future<void> onLoad() async => add(_text);

  void show(String line) {
    _text.text = line;
    _visible = true;
  }

  void hide() {
    _text.text = '';
    _visible = false;
  }

  @override
  void render(Canvas canvas) {
    if (_visible) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(10)),
        _paint,
      );
    }
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

/// The old format's own warning, in its own window.
class _LegacyDialog extends PositionComponent {
  _LegacyDialog()
    : super(
        position: Vector2(kSlideWidth / 2, 330),
        size: Vector2(460, 150),
        anchor: Anchor.center,
        priority: 4,
      );

  @override
  void render(Canvas canvas) {
    final body = paintLegacyWindow(canvas, size, 'Compatibility Mode');
    SlideText.legacyTextBold.render(
      canvas,
      'Q3 Results.sld',
      Vector2(body.left + 14, body.top + 14),
    );
    SlideText.legacyText.render(
      canvas,
      'This deck was last saved in 2003.',
      Vector2(body.left + 14, body.top + 44),
    );
    SlideText.legacyText.render(
      canvas,
      'Some features will not be available.',
      Vector2(body.left + 14, body.top + 70),
    );
  }
}
