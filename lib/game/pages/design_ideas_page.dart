import 'dart:ui';

import 'package:flame/components.dart';

import '../components/chip_button.dart';
import '../components/placeholder_frame.dart';
import '../components/ribbon_bar.dart';
import '../components/setting_controls.dart';
import '../components/status_bar.dart';
import '../input/menu_input.dart';
import '../save/save_data.dart';
import '../slide/fly_in.dart';
import '../slide/slide_metrics.dart';
import '../slide/slide_page.dart';
import '../theme/slide_text.dart';

/// Settings, dressed as PowerPoint's "Design Ideas" task pane.
///
/// Every change is saved the moment it is made and applies straight away;
/// there is no OK button, as there is none on a task pane.
class DesignIdeasPage extends SlidePage {
  static const double _cardsTop = 190;
  static const Color _cardFill = Color(0xFFFBFAF9);
  static const double _columnGap = 30;
  static const double _controlsWidth = 640;
  static const double _sideWidth =
      kSlideWidth - kSlideMargin * 2 - _controlsWidth - _columnGap;
  static const double _sideLeft = kSlideMargin + _controlsWidth + _columnGap;
  static const double _inset = 28;

  late final SettingCheckbox swapSticks;
  late final SettingSlider deadzone;
  late final SettingSlider stickSize;
  late final SettingCheckbox reduceMotion;
  late final TextComponent _motionSource;

  /// Rows sit in two columns, so arrows move by position on the slide.
  @override
  bool get spatialFocus => true;

  @override
  Future<void> onLoad() async {
    final settings = game.settings;
    await addAll([
      RibbonBar(activeTab: 'Design'),
      StatusBar(slideLabel: 'Design Ideas'),
      TextComponent(
        text: 'Design Ideas',
        textRenderer: SlideText.sectionTitle,
        position: Vector2(kSlideMargin, 110),
        anchor: Anchor.centerLeft,
      )..flyIn(delay: 0.05),
      TextComponent(
        text: 'Changes are saved as you make them.',
        textRenderer: SlideText.subtitle,
        position: Vector2(kSlideMargin + 4, 152),
        anchor: Anchor.centerLeft,
      )..flyIn(delay: 0.1),
    ]);

    final rowWidth = _controlsWidth - _inset * 2;
    final controls = _card(
      title: 'Controls',
      position: Vector2(kSlideMargin, _cardsTop),
      size: Vector2(_controlsWidth, 380),
    );
    await controls.addAll([
      swapSticks = SettingCheckbox(
        label: 'Swap sticks',
        checked: settings.swapSticks,
        width: rowWidth,
        position: Vector2(_inset - 6, 76),
        onChanged: (on) => _change((s) => s.copyWith(swapSticks: on)),
      ),
      _caption(
        'Move with the right thumb and aim with the left.',
        Vector2(_inset + 36, 136),
      ),
      deadzone = SettingSlider(
        label: 'Controller dead zone',
        value: settings.deadzone,
        min: Settings.minDeadzone,
        max: Settings.maxDeadzone,
        step: 0.05,
        mark: Settings.defaultDeadzone,
        format: _percent,
        width: rowWidth,
        position: Vector2(_inset - 6, 176),
        onChanged: (value) => _change((s) => s.copyWith(deadzone: value)),
      ),
      _caption(
        'Raise it if the player walks on its own.',
        Vector2(_inset, 236),
      ),
      stickSize = SettingSlider(
        label: 'Thumb stick size',
        value: settings.stickSize,
        min: Settings.minStickSize,
        max: Settings.maxStickSize,
        step: 0.05,
        mark: 1,
        format: _percent,
        width: rowWidth,
        position: Vector2(_inset - 6, 276),
        onChanged: (value) => _change((s) => s.copyWith(stickSize: value)),
      ),
      _caption('The on-screen sticks, for touch.', Vector2(_inset, 336)),
    ]);

    final motion = _card(
      title: 'Motion',
      position: Vector2(_sideLeft, _cardsTop),
      size: Vector2(_sideWidth, 230),
    );
    await motion.addAll([
      reduceMotion = SettingCheckbox(
        label: 'Reduce Motion',
        checked: game.reducesMotion,
        width: _sideWidth - _inset * 2,
        position: Vector2(_inset - 6, 76),
        onChanged: (on) => _change((s) => s.copyWith(reduceMotion: on)),
      ),
      _caption('Entrances, backdrops and hit effects', Vector2(_inset, 140)),
      _caption('keep still. The fight does not.', Vector2(_inset, 164)),
      _motionSource = _caption(_motionSourceText, Vector2(_inset, 200)),
    ]);

    final sound = _card(
      title: 'Sound',
      position: Vector2(_sideLeft, _cardsTop + 250),
      size: Vector2(_sideWidth, 130),
    );
    await sound.add(
      _caption(
        'Music and effect volume, once there is sound.',
        Vector2(_inset, 80),
      ),
    );

    for (final (index, card) in [controls, motion, sound].indexed) {
      await add(card..flyIn(delay: 0.16 + index * 0.07));
    }

    await add(
      ChipButton(
        label: 'Back to Normal View',
        position: Vector2(kSlideMargin, 596),
        width: 250,
        onSelected: game.router.pop,
      )..flyIn(delay: 0.42),
    );
  }

  PlaceholderFrame _card({
    required String title,
    required Vector2 position,
    required Vector2 size,
  }) {
    return PlaceholderFrame(
      position: position,
      size: size,
      fillColor: _cardFill,
    )..add(
      TextComponent(
        text: title,
        textRenderer: SlideText.heading,
        position: Vector2(_inset, 34),
        anchor: Anchor.centerLeft,
      ),
    );
  }

  static TextComponent _caption(String text, Vector2 position) => TextComponent(
    text: text,
    textRenderer: SlideText.caption,
    position: position,
    anchor: Anchor.centerLeft,
  );

  static String _percent(double value) => '${(value * 100).round()}%';

  String get _motionSourceText => game.settings.reduceMotion == null
      ? "Following your device's setting."
      : 'Set here, whatever the device says.';

  void _change(Settings Function(Settings) edit) {
    game.changeSettings(edit(game.settings));
    _motionSource.text = _motionSourceText;
  }

  /// Left and right move a focused slider rather than focus: everywhere else
  /// on the pane they step between columns.
  @override
  void onMenuAction(MenuAction action) {
    final target = focused;
    if (focusVisible &&
        target is SettingSlider &&
        (action == MenuAction.left || action == MenuAction.right)) {
      target.nudge(action == MenuAction.left ? -1 : 1);
      return;
    }
    super.onMenuAction(action);
  }
}
