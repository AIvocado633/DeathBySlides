import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../components/chip_button.dart';
import '../components/ribbon_bar.dart';
import '../components/slide_painting.dart';
import '../components/status_bar.dart';
import '../deck.dart';
import '../levels.dart';
import '../routes.dart';
import '../slide/fly_in.dart';
import '../slide/focusable.dart';
import '../slide/slide_metrics.dart';
import '../slide/slide_page.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';

/// Level select, dressed as the editor's light table: every slide at once.
class SlideSorterPage extends SlidePage {
  static const double _thumbWidth = 280;
  static const double _thumbHeight = 158;
  static const double _gapX = 40;

  /// Room for a row's two caption lines and the next row's slide numbers,
  /// which sit above their thumbnails.
  static const double _gapY = 106;
  static const int _columns = 3;
  static const double _gridTop = 190;

  @override
  Future<void> onLoad() async {
    await addAll([
      RibbonBar(activeTab: 'Arrange'),
      StatusBar(slideLabel: 'Light table · ${kLevels.length} slides'),
      TextComponent(
        text: 'Light Table',
        textRenderer: SlideText.sectionTitle,
        position: Vector2(kSlideMargin, 100),
        anchor: Anchor.centerLeft,
      )..flyIn(delay: 0.05),
      TextComponent(
        text: 'Pick the feature you are prepared to argue with.',
        textRenderer: SlideText.subtitle,
        position: Vector2(kSlideMargin + 4, 140),
        anchor: Anchor.centerLeft,
      )..flyIn(delay: 0.1),
    ]);

    const gridWidth = _columns * _thumbWidth + (_columns - 1) * _gapX;
    final originX = (kSlideWidth - gridWidth) / 2;

    final deck = game.deck;
    for (final (index, level) in kLevels.indexed) {
      final column = index % _columns;
      final row = index ~/ _columns;
      await add(
        SlideThumbnail(
          level: level,
          state: deck.stateOf(level.number),
          position: Vector2(
            originX + column * (_thumbWidth + _gapX),
            _gridTop + row * (_thumbHeight + _gapY),
          ),
          size: Vector2(_thumbWidth, _thumbHeight),
          onSelected: () =>
              game.router.pushNamed(Routes.slideShowFor(level.number)),
        )..flyIn(delay: 0.16 + index * 0.05),
      );
    }

    // Top-right, so it stays clear of the second row's captions.
    await add(
      ChipButton(
        label: 'Back to Editing',
        position: Vector2(kSlideWidth - kSlideMargin - 250, 92),
        width: 250,
        onSelected: game.router.pop,
      )..flyIn(from: Vector2(120, 0), delay: 0.5),
    );
  }

  /// The thumbnails are a grid, so arrows move across it by position.
  @override
  bool get spatialFocus => true;

  /// Focus starts on the slide the player is up to, not on the way out.
  @override
  Focusable? get initialFocus {
    final current = game.deck.currentSlide;
    return children
            .whereType<SlideThumbnail>()
            .where((thumbnail) => thumbnail.level.number == current)
            .firstOrNull ??
        super.initialFocus;
  }

  /// Winning a slide opened from here marks it beaten and unlocks the next.
  @override
  void onProgressChanged() {
    final deck = game.deck;
    for (final thumbnail in children.whereType<SlideThumbnail>()) {
      thumbnail.state = deck.stateOf(thumbnail.level.number);
    }
  }
}

/// One slide thumbnail on the light table, marked the way slide overviews
/// mark slides:
///
///  * beaten: a small star, as editors put by slides that have animations;
///  * unlocked: a plain slide;
///  * locked: greyed out, with a bolt;
///  * not built yet: a hidden slide, faded, with its number struck through.
///    Unlike a lock, that does not suggest it could be earned.
///
/// Every thumbnail can take focus, locked or not, the way any slide in the
/// sorter can be selected; only playable ones open.
class SlideThumbnail extends PositionComponent
    with TapCallbacks, HoverCallbacks, Focusable {
  SlideThumbnail({
    required this.level,
    required SlideState state,
    required this.onSelected,
    required Vector2 position,
    required Vector2 size,
  }) : _state = state,
       super(position: position, size: size);

  final LevelDefinition level;
  final void Function() onSelected;

  SlideState get state => _state;
  SlideState _state;
  set state(SlideState value) {
    _state = value;
    if (isLoaded) {
      _title.textRenderer = _titleRenderer;
    }
  }

  bool get isPlayable =>
      _state == SlideState.beaten || _state == SlideState.unlocked;

  bool get _isLocked => _state == SlideState.locked;

  late final TextComponent _title;
  late final double _numberWidth;

  final Paint _surfacePaint = Paint()..color = Palette.slide;
  final Paint _lockedSurfacePaint = Paint()..color = const Color(0xFFF1ECE2);
  final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _bulletPaint = Paint()..color = Palette.brand;
  final Paint _lockedBulletPaint = Paint()..color = Palette.locked;
  final Paint _linePaint = Paint()..color = Palette.rule;
  final Paint _strikePaint = Paint()
    ..color = Palette.inkSoft
    ..strokeWidth = 2;

  /// Draws a hidden slide, children included, at under half strength.
  final Paint _hiddenPaint = Paint()..color = const Color(0x73000000);

  TextPaint get _titleRenderer =>
      _isLocked ? SlideText.thumbnailTitleLocked : SlideText.thumbnailTitle;

  @override
  Future<void> onLoad() async {
    final number = '${level.number}';
    _numberWidth = SlideText.thumbnailNumber.getLineMetrics(number).width;
    addAll([
      TextComponent(
        text: number,
        textRenderer: SlideText.thumbnailNumber,
        position: Vector2(0, -10),
        anchor: Anchor.bottomLeft,
      ),
      _title = TextComponent(
        text: level.boss,
        textRenderer: _titleRenderer,
        position: Vector2(0, height + 16),
      ),
      TextComponent(
        text: level.tagline,
        textRenderer: SlideText.thumbnailSubtitle,
        position: Vector2(0, height + 44),
      ),
    ]);
  }

  @override
  void renderTree(Canvas canvas) {
    if (_state != SlideState.notBuilt) {
      super.renderTree(canvas);
      return;
    }
    canvas.saveLayer(null, _hiddenPaint);
    super.renderTree(canvas);
    canvas.restore();
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    canvas.drawRect(rect, _isLocked ? _lockedSurfacePaint : _surfacePaint);

    // A miniature of the slide's content: a title bar and two bullet lines.
    final bullet = _isLocked ? _lockedBulletPaint : _bulletPaint;
    canvas.drawRect(Rect.fromLTWH(22, 26, 150, 14), bullet);
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(22, 66.0 + i * 22, 210 - i * 34, 8),
        _linePaint,
      );
    }

    // The slide number sits above the thumbnail, centred on y = -21.
    switch (_state) {
      case SlideState.beaten:
        canvas.drawPath(
          starPath(Offset(_numberWidth + 16, -21), 9),
          _bulletPaint,
        );
      case SlideState.locked:
        canvas.drawPath(
          boltPath(Offset(width - 46, height - 42), 40),
          _lockedBulletPaint,
        );
      case SlideState.notBuilt:
        canvas.drawLine(
          Offset(-3, -11),
          Offset(_numberWidth + 3, -31),
          _strikePaint,
        );
      case SlideState.unlocked:
        break;
    }

    // Selected the way an overview selects a slide: a thick border in
    // the brand colour, rather than the resize handles used for shapes.
    if (isHighlighted) {
      _borderPaint
        ..color = Palette.brand
        ..strokeWidth = 5;
      canvas.drawRect(rect.inflate(1.5), _borderPaint);
    } else {
      _borderPaint
        ..color = Palette.rule
        ..strokeWidth = 2;
      canvas.drawRect(rect, _borderPaint);
    }
  }

  @override
  void onTapUp(TapUpEvent event) => select();

  @override
  void activate() => select();

  /// Opens the slide, if it can be opened.
  void select() {
    if (isPlayable) {
      onSelected();
    }
  }
}
