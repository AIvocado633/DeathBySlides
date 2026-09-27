import 'package:flame/components.dart';

import '../components/chip_button.dart';
import '../components/placeholder_frame.dart';
import '../components/setting_controls.dart';
import '../components/status_bar.dart';
import '../components/toolbar.dart';
import '../save/save_data.dart';
import '../slide/fly_in.dart';
import '../slide/slide_metrics.dart';
import '../slide/slide_page.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';

/// Pep Talk: the assists, each switched on on its own rather than as one
/// "easy mode", opened from Tweaks.
///
/// Like Tweaks, every change is saved and applies straight away. Tweaks is not
/// reachable mid-fight, so a change always lands between slides.
class PepTalkPage extends SlidePage {
  static const double _cardTop = 190;
  static const double _inset = 28;
  static const double _rowGap = 88;

  late final SettingCheckbox moreRoom;
  late final SettingCheckbox slowerShots;
  late final SettingCheckbox longerGrace;
  late final SettingCheckbox aimAssist;

  @override
  Future<void> onLoad() async {
    final pepTalk = game.settings.pepTalk;
    await addAll([
      Toolbar(activeTab: 'Tweak'),
      StatusBar(slideLabel: 'Tweaks · Pep Talk'),
      TextComponent(
        text: 'Pep Talk',
        textRenderer: SlideText.sectionTitle,
        position: Vector2(kSlideMargin, 110),
        anchor: Anchor.centerLeft,
      )..flyIn(delay: 0.05),
      TextComponent(
        text: 'Help for the fights. Nothing is held back while it is on.',
        textRenderer: SlideText.subtitle,
        position: Vector2(kSlideMargin + 4, 152),
        anchor: Anchor.centerLeft,
      )..flyIn(delay: 0.1),
    ]);

    const cardWidth = kSlideWidth - kSlideMargin * 2;
    final card = PlaceholderFrame(
      position: Vector2(kSlideMargin, _cardTop),
      size: Vector2(cardWidth, 380),
      fillColor: Palette.card,
    );
    const rowWidth = cardWidth - _inset * 2;

    SettingCheckbox row(
      int index, {
      required String label,
      required bool checked,
      required PepTalk Function(PepTalk, bool) change,
    }) => SettingCheckbox(
      label: label,
      checked: checked,
      width: rowWidth,
      position: Vector2(_inset - 6, 26 + index * _rowGap),
      onChanged: (on) => _change((p) => change(p, on)),
    );

    await card.addAll([
      moreRoom = row(
        0,
        label: 'More room to shrink',
        checked: pepTalk.moreRoom,
        change: (p, on) => p.copyWith(moreRoom: on),
      ),
      _caption(
        'Take ${PepTalk.roomyHits} hits instead of ${PepTalk.normalHits} '
        'before shrinking away.',
        0,
      ),
      slowerShots = row(
        1,
        label: 'Slower shots',
        checked: pepTalk.slowerShots,
        change: (p, on) => p.copyWith(slowerShots: on),
      ),
      _caption(
        'Everything thrown at you flies at '
        '${(PepTalk.slowShotScale * 100).round()}% speed.',
        1,
      ),
      longerGrace = row(
        2,
        label: 'Longer grace',
        checked: pepTalk.longerGrace,
        change: (p, on) => p.copyWith(longerGrace: on),
      ),
      _caption('Stay untouchable twice as long after a hit.', 2),
      aimAssist = row(
        3,
        label: 'Aim assist',
        checked: pepTalk.aimAssist,
        change: (p, on) => p.copyWith(aimAssist: on),
      ),
      _caption('Bullet points bend gently towards a target just ahead.', 3),
    ]);
    await add(card..flyIn(delay: 0.16));

    await add(
      ChipButton(
        label: 'Back to Tweaks',
        position: Vector2(kSlideMargin, 596),
        width: 250,
        onSelected: game.router.pop,
      )..flyIn(delay: 0.3),
    );
  }

  static TextComponent _caption(String text, int row) => TextComponent(
    text: text,
    textRenderer: SlideText.caption,
    position: Vector2(_inset + 36, 26 + row * _rowGap + 64),
    anchor: Anchor.centerLeft,
  );

  void _change(PepTalk Function(PepTalk) edit) {
    final settings = game.settings;
    game.changeSettings(settings.copyWith(pepTalk: edit(settings.pepTalk)));
  }
}
