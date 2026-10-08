import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';

import '../combat/legacy_format_boss.dart' show paintLegacyWindow;
import '../components/chip_button.dart';
import '../components/placeholder_frame.dart';
import '../components/shape_actor.dart';
import '../components/status_bar.dart';
import '../components/toolbar.dart';
import '../input/menu_input.dart';
import '../slide/focusable.dart';
import '../slide/motion.dart';
import '../slide/slide_metrics.dart';
import '../slide/slide_page.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';

/// A scene of the story: the intro, or one of the scenes between slides.
///
/// Every cutscene is a list of beats on one timeline, planned in [plan] with
/// [at]. With [Motion.reduced] the beats still come on time, but nothing
/// moves: [ease] and [glide] put things straight where they end. A *Skip*
/// chip, or any tap, key or button after [skipDelay], skips it -- together
/// with any other scenes queued after it.
///
/// When it ends, the game goes on to whatever was queued after it: the fight
/// it leads into, the next scene of a replay, or back to the page beneath.
abstract class CutscenePage extends SlidePage with TapCallbacks {
  /// How long presses are ignored, so the press that opened the scene does
  /// not skip it straight away.
  static const double skipDelay = 1;

  /// How long the scene runs, in seconds.
  double get length;

  /// Seconds since the scene started.
  double get elapsed => _elapsed;
  double _elapsed = 0;

  /// The narration showing now.
  String get caption => _caption.text;

  bool get isFinished => _finished;
  bool _finished = false;

  final List<({double at, void Function() run})> _beats = [];
  int _nextBeat = 0;

  late final _Caption _caption;
  late final ChipButton _skip;

  /// Black over everything but the caption, for scenes off the slide.
  late final RectangleComponent blackout;

  /// Builds the scenery the first beats need.
  Future<void> build();

  /// Schedules every beat with [at].
  void plan();

  /// Records that this scene has been seen, so it plays once.
  void markSeen();

  @override
  Future<void> onLoad() async {
    blackout = RectangleComponent(
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
      onSelected: () => finish(skipping: true),
    )..priority = 7;
    await build();
    await addAll([blackout, _caption, _skip]);
    plan();
    at(length, finish);
    _beats.sort((a, b) => a.at.compareTo(b.at));
    // The first beats are there from the first frame.
    _runDueBeats();
  }

  /// Runs [run] [seconds] into the scene.
  void at(double seconds, void Function() run) =>
      _beats.add((at: seconds, run: run));

  /// Puts [line] in the caption strip.
  void say(String line) => _caption.show(line);

  void hideCaption() => _caption.hide();

  /// Eases [component] to [scale], or puts it there with Reduce Motion.
  void ease(PositionComponent component, {required Vector2 scale}) {
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

  /// Glides [component] to [to], or puts it there with Reduce Motion.
  void glide(
    PositionComponent component,
    Vector2 to, {
    double duration = 0.35,
  }) {
    if (Motion.reduced) {
      component.position = to;
      return;
    }
    component.add(
      MoveEffect.to(
        to,
        EffectController(duration: duration, curve: Curves.easeInOutCubic),
      ),
    );
  }

  /// Pops [component] in from nothing, onto [parent].
  void popIn(Component parent, PositionComponent component) {
    parent.add(component);
    component.scale = Vector2.zero();
    ease(component, scale: Vector2.all(1));
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

  void _runDueBeats() {
    while (_nextBeat < _beats.length && _beats[_nextBeat].at <= _elapsed) {
      _beats[_nextBeat++].run();
      if (_finished) {
        return;
      }
    }
  }

  /// Ends the scene: it is marked seen, and the game goes on to what was
  /// queued after it. [skipping] skips every other scene queued too.
  void finish({bool skipping = false}) {
    if (_finished) {
      return;
    }
    _finished = true;
    markSeen();
    game.continueStory(skipping: skipping);
  }

  void _skipByPress() {
    if (_elapsed >= skipDelay) {
      finish(skipping: true);
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

/// The editor the story mostly happens in: toolbar, status bar with the
/// time, a title, a body box and the presenter, built on [parent].
class EditorScene {
  EditorScene(
    this.parent, {
    required String clock,
    String title = 'Q3 Results',
    bool bullets = true,
    Vector2? presenterAt,
  }) {
    presenter = ShapeActor(
      actor: 'hero',
      position: presenterAt ?? Vector2(1000, 330),
      size: Vector2.all(240),
      anchor: Anchor.center,
    );
    this.title = TextComponent(
      text: title,
      textRenderer: SlideText.titleInk,
      position: Vector2(kSlideMargin + 28, 160),
      anchor: Anchor.centerLeft,
    );
    this.bullets = [
      for (final (i, line) in ['Revenue', 'Costs', 'Hope'].indexed)
        TextComponent(
          text: '•  $line',
          textRenderer: SlideText.bullet,
          position: Vector2(kSlideMargin + 40, 300.0 + i * 64),
          anchor: Anchor.centerLeft,
        ),
    ];
    toolbar = Toolbar(activeTab: 'Edit');
    statusBar = StatusBar(
      slideLabel: 'Slide 1 of 1',
      detailLabel: 'Autosaved $clock',
    );
    parent.addAll([
      toolbar,
      statusBar,
      PlaceholderFrame(
        position: Vector2(kSlideMargin, 100),
        size: Vector2(700, 120),
      ),
      PlaceholderFrame(
        position: Vector2(kSlideMargin, 250),
        size: Vector2(700, 270),
      ),
      this.title,
      if (bullets) ...this.bullets,
      presenter,
    ]);
  }

  final PositionComponent parent;
  late final ShapeActor presenter;
  late final TextComponent title;
  late final List<TextComponent> bullets;
  late Toolbar toolbar;
  late StatusBar statusBar;

  /// Switches the toolbar to [tab], as if the presenter clicked it.
  void openTab(String tab) {
    toolbar.removeFromParent();
    parent.add(toolbar = Toolbar(activeTab: tab));
  }

  /// Puts [detail] in the status bar.
  void status(String detail) {
    statusBar.removeFromParent();
    parent.add(
      statusBar = StatusBar(slideLabel: 'Slide 1 of 1', detailLabel: detail),
    );
  }

  /// A feature turning up to wreck the slide: it pops in, and the presenter
  /// flinches.
  ShapeActor cameo(CutscenePage page, String actor, Color tint, Vector2 at) {
    presenter.hit();
    final cameo = ShapeActor(
      actor: actor,
      tint: tint,
      position: at,
      size: Vector2.all(130),
      anchor: Anchor.center,
    );
    page.popIn(parent, cameo);
    return cameo;
  }

  /// A wash of [colour] over the whole slide.
  void tint(Color colour) => parent.add(
    RectangleComponent(
      position: Vector2(0, kContentTop),
      size: Vector2(kSlideWidth, kContentBottom - kContentTop),
      paint: Paint()..color = colour,
    ),
  );
}

/// The editor's own kind of dialog: a question, and only one answer.
class EditorDialog extends PositionComponent {
  EditorDialog({
    required this.title,
    required this.message,
    required this.button,
    required super.position,
  }) : super(size: Vector2(440, 170), anchor: Anchor.center, priority: 4);

  final String title;
  final String message;
  final String button;

  final Paint _card = Paint()..color = Palette.slide;
  final Paint _header = Paint()..color = Palette.brand;
  final Paint _shadow = Paint()
    ..color = const Color(0x66000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

  @override
  void render(Canvas canvas) {
    final card = size.toRect();
    canvas
      ..drawRect(card.deflate(6), _shadow)
      ..drawRect(card, _card)
      ..drawRect(Rect.fromLTWH(0, 0, width, 44), _header);
    SlideText.chipOnBrand.render(
      canvas,
      title,
      Vector2(18, 22),
      anchor: Anchor.centerLeft,
    );
    SlideText.caption.render(
      canvas,
      message,
      Vector2(18, 76),
      anchor: Anchor.centerLeft,
    );
    final buttonRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(width - 172, height - 58, 154, 42),
      const Radius.circular(21),
    );
    canvas.drawRRect(buttonRect, _header);
    SlideText.chipOnBrand.render(
      canvas,
      button,
      Vector2(buttonRect.center.dx, buttonRect.center.dy),
      anchor: Anchor.center,
    );
  }
}

/// A 2003-era window, with a few lines of bad news.
class LegacyDialog extends PositionComponent {
  LegacyDialog({required this.title, required this.lines})
    : super(
        position: Vector2(kSlideWidth / 2, 330),
        size: Vector2(460, 150),
        anchor: Anchor.center,
        priority: 4,
      );

  final String title;

  /// The first line is set in bold.
  final List<String> lines;

  @override
  void render(Canvas canvas) {
    final body = paintLegacyWindow(canvas, size, title);
    for (final (i, line) in lines.indexed) {
      (i == 0 ? SlideText.legacyTextBold : SlideText.legacyText).render(
        canvas,
        line,
        Vector2(body.left + 14, body.top + 14 + i * 28),
      );
    }
  }
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
