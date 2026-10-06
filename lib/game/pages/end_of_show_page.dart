import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../audio/game_audio.dart';
import '../input/menu_input.dart';
import '../routes.dart';
import '../slide/slide_metrics.dart';
import '../slide/slide_page.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';

/// The black slide every slide show ends on: *End of slide show, click to
/// exit.* Reached by winning the deck's last slide.
///
/// The credits sit in the speaker notes, where a presenter keeps everything
/// the audience was never meant to read. Any tap, key or button goes back to
/// the title slide.
class EndOfShowPage extends SlidePage with TapCallbacks {
  /// How long presses are ignored, so a player still hammering fire as the
  /// last feature goes down does not skip the ending unseen.
  static const double inputDelay = 1;

  /// The speaker notes, line by line.
  static const List<String> speakerNotes = [
    'Death by Slides. Made by AIvocado633.',
    'Built with Flutter and the Flame engine; controllers through the gamepads package.',
    'Type: Atkinson Hyperlegible, by the Braille Institute, under the SIL Open Font License.',
    'Sound: every effect and both music loops were synthesised for this game by',
    'tool/make_sounds.py and are released under CC0 (see assets/audio/CREDITS.md).',
    'Not affiliated with or endorsed by the makers of any presentation software.',
  ];

  static const double _notesTop = 380;
  static const double _notesHeight = 270;

  @override
  Color get surfaceColor => Palette.showBlack;

  @override
  bool get castsShadow => false;

  /// The applause from the last win carries on into the quiet.
  @override
  Track? get music => null;

  double _shownFor = 0;
  bool _leaving = false;

  /// Whether a press would leave now.
  bool get acceptsInput => _shownFor >= inputDelay;

  @override
  Future<void> onLoad() async {
    await addAll([
      TextComponent(
        text: 'End of slide show, click to exit.',
        textRenderer: SlideText.showBody,
        position: Vector2(kSlideWidth / 2, 180),
        anchor: Anchor.center,
      ),
      _SpeakerNotes(
        position: Vector2(kSlideMargin, _notesTop),
        size: Vector2(kSlideWidth - kSlideMargin * 2, _notesHeight),
      ),
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _shownFor += dt;
  }

  /// Back to the title slide, which by now knows the deck is done.
  void exit() {
    if (_leaving || !acceptsInput) {
      return;
    }
    _leaving = true;
    game.router.popUntilNamed(Routes.normalView);
  }

  @override
  void onAnyPress() => exit();

  @override
  void onMenuAction(MenuAction action) => exit();

  @override
  void onTapUp(TapUpEvent event) => exit();
}

/// The notes pane under a slide, holding the credits.
class _SpeakerNotes extends PositionComponent {
  _SpeakerNotes({required super.position, required super.size});

  static const double _lineHeight = 30;

  final Paint _panePaint = Paint()..color = Palette.toolbar;
  final Paint _edgePaint = Paint()
    ..color = Palette.toolbarEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  Future<void> onLoad() async {
    await addAll([
      TextComponent(
        text: 'Speaker notes',
        textRenderer: SlideText.paneTitle,
        position: Vector2(24, 30),
        anchor: Anchor.centerLeft,
      ),
      for (final (i, line) in EndOfShowPage.speakerNotes.indexed)
        TextComponent(
          text: line,
          textRenderer: SlideText.notes,
          position: Vector2(24, 76 + i * _lineHeight),
          anchor: Anchor.centerLeft,
        ),
    ]);
  }

  @override
  void render(Canvas canvas) {
    final pane = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(8),
    );
    canvas
      ..drawRRect(pane, _panePaint)
      ..drawRRect(pane, _edgePaint);
  }
}
