import 'dart:ui';

import 'package:flame/components.dart';

import '../components/autoshape_backdrop.dart';
import '../components/chip_button.dart';
import '../components/menu_bullet_button.dart';
import '../components/placeholder_frame.dart';
import '../components/shape_actor.dart';
import '../components/toolbar.dart';
import '../components/status_bar.dart';
import '../input/menu_input.dart';
import '../levels.dart';
import '../routes.dart';
import '../slide/fly_in.dart';
import '../slide/slide_metrics.dart';
import '../slide/slide_page.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';

/// The start menu: slide 1 of the deck, still sitting in normal editing view.
class MainMenuPage extends SlidePage {
  static const double _titleLeft = kSlideMargin;
  static const double _titleTop = 100;
  static const double _panelLeft = 840;
  static const double _panelWidth = 364;

  /// The parts of the slide that show progress, rebuilt when it changes.
  late StatusBar _statusBar;
  late MenuBulletButton _startButton;
  late TextComponent _footer;
  late ShapeActor _hero;
  late TextComponent _heroCaption;

  @override
  Future<void> onLoad() async {
    await addAll([
      AutoshapeBackdrop(seed: 7),
      Toolbar(activeTab: 'Present'),
      _statusBar = _buildStatusBar(),
    ]);

    await add(_buildTitle());
    await add(_buildSubtitle());
    await addAll(_buildMenu());
    await add(_buildOnStagePanel());
    await add((_footer = _buildFooter())..flyIn(delay: 0.5));
  }

  /// Swaps in the new versions where they stand, without flying them in
  /// again: the slide has already been built once.
  @override
  void onProgressChanged() {
    _statusBar.removeFromParent();
    _startButton.removeFromParent();
    _footer.removeFromParent();
    addAll([
      _statusBar = _buildStatusBar(),
      _startButton = _buildStartButton(),
      _footer = _buildFooter(),
    ]);
    _hero.cheering = game.deck.isFinished;
    _heroCaption.text = _heroCaptionText;
  }

  /// The usual presenting shortcuts: F5 shows from the beginning, Shift+F5
  /// from the current slide.
  @override
  void onMenuAction(MenuAction action) {
    switch (action) {
      case MenuAction.startFromBeginning:
        game.router.pushNamed(Routes.slideShowFor(kLevels.first.number));
      case MenuAction.startFromCurrent:
        game.router.pushNamed(Routes.slideShowFor(game.deck.currentSlide));
      default:
        super.onMenuAction(action);
    }
  }

  /// The title slide is the bottom of the deck: there is nothing to go back
  /// to. (Android's back gesture leaves the app from here instead.)
  @override
  void onBack() {}

  /// Where the deck stands: the slide to carry on from, or the whole deck
  /// presented.
  StatusBar _buildStatusBar() {
    final deck = game.deck;
    final where = 'Slide ${deck.currentSlide} of ${kLevels.length}';
    return StatusBar(slideLabel: deck.isFinished ? '$where · Presented' : where);
  }

  String get _heroCaptionText => game.deck.isFinished
      ? 'Shape 1 · presented the whole deck'
      : 'Shape 1 · rectangles and hope';

  PositionComponent _buildTitle() {
    final frame = PlaceholderFrame(
      position: Vector2(_titleLeft, _titleTop),
      size: Vector2(730, 150),
    );
    const brandWord = 'DEATH BY ';
    final brandWidth = SlideText.titleBrand.getLineMetrics(brandWord).width;
    frame.addAll([
      TextComponent(
        text: brandWord,
        textRenderer: SlideText.titleBrand,
        position: Vector2(28, 75),
        anchor: Anchor.centerLeft,
      ),
      TextComponent(
        text: 'SLIDES',
        textRenderer: SlideText.titleInk,
        position: Vector2(28 + brandWidth, 75),
        anchor: Anchor.centerLeft,
      ),
      _Caret(position: Vector2(28 + brandWidth + _slidesWidth + 10, 75)),
    ]);
    return frame..flyIn(delay: 0.05);
  }

  static final double _slidesWidth =
      SlideText.titleInk.getLineMetrics('SLIDES').width;

  PositionComponent _buildSubtitle() {
    return TextComponent(
      text: 'Click to defeat the features that defeated you.',
      textRenderer: SlideText.subtitle,
      position: Vector2(_titleLeft + 30, 282),
      anchor: Anchor.centerLeft,
    )..flyIn(delay: 0.16);
  }

  List<PositionComponent> _buildMenu() {
    final entries = <({String label, String? hint, String route})>[
      (
        label: 'Light Table',
        hint: 'Levels',
        route: Routes.lightTable,
      ),
      (
        label: 'Tweaks',
        hint: 'Settings',
        route: Routes.tweaks,
      ),
    ];

    return [
      (_startButton = _buildStartButton())..flyIn(delay: 0.24),
      for (final (index, entry) in entries.indexed)
        MenuBulletButton(
          label: entry.label,
          hint: entry.hint,
          position: _menuEntryPosition(index + 1),
          onSelected: () => game.router.pushNamed(entry.route),
        )..flyIn(delay: 0.24 + (index + 1) * 0.08),
    ];
  }

  static Vector2 _menuEntryPosition(int index) =>
      Vector2(_titleLeft - 4, 336 + index * 78);

  /// Starts the show where a presenter would: from the beginning until there
  /// is progress, then from the first slide not won yet, and from the
  /// beginning again once every built slide has been.
  MenuBulletButton _buildStartButton() {
    final deck = game.deck;
    final resume = deck.resumeSlide;
    final entry = !deck.hasProgress
        ? (label: 'Start Presenting', hint: 'F5', slide: kLevels.first.number)
        : resume == null
        ? (label: 'From the Top', hint: 'F5', slide: kLevels.first.number)
        : (label: 'Carry On', hint: 'Shift+F5', slide: resume);
    return MenuBulletButton(
      label: entry.label,
      hint: entry.hint,
      position: _menuEntryPosition(0),
      onSelected: () => game.router.pushNamed(Routes.slideShowFor(entry.slide)),
    );
  }

  PositionComponent _buildOnStagePanel() {
    final panel = PlaceholderFrame(
      position: Vector2(_panelLeft, _titleTop),
      size: Vector2(_panelWidth, 520),
      fillColor: Palette.card,
    );

    const actorSize = 230.0;
    final actorTopLeft = Vector2((_panelWidth - actorSize) / 2, 110);

    panel.addAll([
      TextComponent(
        text: 'ON STAGE',
        textRenderer: SlideText.panelHeading,
        position: Vector2(_panelWidth / 2, 34),
        anchor: Anchor.center,
      ),
      // Pleased with itself, for once, when the deck has been presented.
      _hero = ShapeActor(
        actor: 'hero',
        position: actorTopLeft,
        size: Vector2.all(actorSize),
      )..cheering = game.deck.isFinished,
      SelectionHandles(
        position: actorTopLeft - Vector2.all(10),
        size: Vector2.all(actorSize + 20),
      ),
      TextComponent(
        text: 'The Presenter',
        textRenderer: SlideText.heading,
        position: Vector2(_panelWidth / 2, 384),
        anchor: Anchor.center,
      ),
      _heroCaption = TextComponent(
        text: _heroCaptionText,
        textRenderer: SlideText.caption,
        position: Vector2(_panelWidth / 2, 420),
        anchor: Anchor.center,
      ),
      // The presenter's story: the intro, again.
      ChipButton(
        label: 'The Night Before',
        position: Vector2(_panelWidth / 2, 476),
        anchor: Anchor.center,
        width: 240,
        height: 44,
        onSelected: () => game.router.pushNamed(Routes.intro),
      ),
    ]);

    return panel..flyIn(from: Vector2(120, 0), delay: 0.3);
  }

  TextComponent _buildFooter() {
    return TextComponent(
      text: footerLine(game.deck.featuresLeft),
      textRenderer: SlideText.caption,
      position: Vector2(_titleLeft + 30, 610),
      anchor: Anchor.centerLeft,
    );
  }

  static const _counts = ['One', 'Two', 'Three', 'Four', 'Five', 'Six'];

  /// The footer, counting down the features still in the way.
  static String footerLine(int featuresLeft) {
    if (featuresLeft == 0) {
      return 'Nothing stands between you and the end of the deck.';
    }
    final count = featuresLeft <= _counts.length
        ? _counts[featuresLeft - 1]
        : '$featuresLeft';
    return featuresLeft == 1
        ? '$count feature stands between you and the end of the deck.'
        : '$count features stand between you and the end of the deck.';
  }
}

/// The text cursor that blinks at the end of the title, as if the deck is
/// still being typed.
class _Caret extends PositionComponent {
  _Caret({required Vector2 position})
    : super(position: position, size: Vector2(4, 66), anchor: Anchor.centerLeft);

  static const double _blinkPeriod = 0.55;

  double _elapsed = 0;
  bool _visible = true;

  final Paint _paint = Paint()..color = Palette.ink;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _blinkPeriod) {
      _elapsed -= _blinkPeriod;
      _visible = !_visible;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_visible) {
      canvas.drawRect(size.toRect(), _paint);
    }
  }
}
