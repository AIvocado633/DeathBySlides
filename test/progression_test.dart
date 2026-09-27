import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pptx_monsters/game/components/player.dart';
import 'package:pptx_monsters/game/components/chip_button.dart';
import 'package:pptx_monsters/game/components/menu_bullet_button.dart';
import 'package:pptx_monsters/game/components/result_panel.dart';
import 'package:pptx_monsters/game/components/status_bar.dart';
import 'package:pptx_monsters/game/deck.dart';
import 'package:pptx_monsters/game/levels.dart';
import 'package:pptx_monsters/game/pages/arena_page.dart';
import 'package:pptx_monsters/game/pages/main_menu_page.dart';
import 'package:pptx_monsters/game/pages/slide_sorter_page.dart';
import 'package:pptx_monsters/game/pptx_monsters_game.dart';
import 'package:pptx_monsters/game/routes.dart';
import 'package:pptx_monsters/game/save/save_data.dart';
import 'package:pptx_monsters/game/save/save_store.dart';

import 'arena_harness.dart';

/// A deck of four slides, the last one not built, so the rules are tested
/// independently of how many bosses exist today.
List<LevelDefinition> _levels() => [
  for (final number in [1, 2, 3, 4])
    LevelDefinition(
      number: number,
      boss: 'Feature $number',
      tagline: '',
      winLine: '',
      lossLine: '',
      buildBoss: number < 4 ? kLevels.first.buildBoss : null,
    ),
];

Deck _deck(Set<int> beaten, {bool unlockAll = false}) => Deck(
  levels: _levels(),
  progress: Progress(beaten: beaten),
  unlockAll: unlockAll,
);

void main() {
  group('deck', () {
    test('opens only the first slide on a fresh start', () {
      final deck = _deck({});

      expect(
        [
          for (final n in [1, 2, 3, 4]) deck.stateOf(n),
        ],
        [
          SlideState.unlocked,
          SlideState.locked,
          SlideState.locked,
          SlideState.notBuilt,
        ],
      );
    });

    test('unlocks the slide after each beaten one', () {
      final deck = _deck({1, 2});

      expect(
        [
          for (final n in [1, 2, 3, 4]) deck.stateOf(n),
        ],
        [
          SlideState.beaten,
          SlideState.beaten,
          SlideState.unlocked,
          SlideState.notBuilt,
        ],
      );
      expect(deck.isPlayable(1), isTrue, reason: 'beaten slides replay');
    });

    test('never opens a slide that has not been built', () {
      expect(_deck({1, 2, 3}).isPlayable(4), isFalse);
      expect(_deck({}, unlockAll: true).isPlayable(4), isFalse);
    });

    test('the unlock-all switch opens every built slide', () {
      final deck = _deck({}, unlockAll: true);

      expect([
        for (final n in [1, 2, 3]) deck.isPlayable(n),
      ], everyElement(isTrue));
    });

    test('resumes from the first slide not won yet', () {
      expect(_deck({}).resumeSlide, 1);
      expect(_deck({1}).resumeSlide, 2);
      expect(_deck({1, 2}).resumeSlide, 3);
      // Slides won out of order, with the switch on, still resume from a gap.
      expect(_deck({2}, unlockAll: true).resumeSlide, 1);
      expect(
        _deck({1, 2, 3}).resumeSlide,
        isNull,
        reason: 'every built slide has been won',
      );
    });

    test('offers a next slide only when it has been built', () {
      expect(_deck({1}).nextAfter(1), 2);
      expect(_deck({1, 2, 3}).nextAfter(3), isNull);
      expect(_deck({1, 2, 3, 4}).nextAfter(4), isNull);
    });

    test('counts down the features left, built or not', () {
      expect(_deck({}).featuresLeft, 4);
      expect(_deck({1, 2}).featuresLeft, 2);
    });
  });

  group('footer', () {
    test('counts down in words', () {
      expect(
        MainMenuPage.footerLine(6),
        'Six features stand between you and the end of the deck.',
      );
      expect(
        MainMenuPage.footerLine(1),
        'One feature stands between you and the end of the deck.',
      );
      expect(
        MainMenuPage.footerLine(0),
        'Nothing stands between you and the end of the deck.',
      );
    });
  });

  group('the slide show', () {
    final store = InMemorySaveStore();
    testWithGame<PptxMonstersGame>(
      'beating a slide unlocks the next one, and keeps it unlocked',
      () => PptxMonstersGame(saveStore: store),
      (game) async {
        await _started(game);
        expect(game.deck.isPlayable(2), isFalse);

        await _win(game, await openArena(game));

        expect(game.deck.isPlayable(2), isTrue);
        final reloaded = SaveData.decode(store.document!);
        expect(
          Deck(progress: reloaded.progress).isPlayable(2),
          isTrue,
          reason: 'still unlocked after a restart',
        );
      },
    );

    testWithGame<PptxMonstersGame>(
      'a win offers Next Slide first, which opens the next slide afresh',
      PptxMonstersGame.new,
      (game) async {
        await _win(game, await openArena(game));

        final panel = _panel(game);
        expect(_labels(panel), ['Next Slide', 'Retry Slide', 'Walk Off']);
        expect(_button(panel, 'Next Slide').filled, isTrue);

        _button(panel, 'Next Slide').onSelected();
        await game.ready();

        final arena = _arena(game);
        expect(arena.level.number, 2);
        expect(arena.isResolved, isFalse);
        expect(game.router.currentRoute.name, Routes.slideShowFor(2));
        game.router.pop();
        await game.ready();
        expect(
          game.router.currentRoute.name,
          Routes.normalView,
          reason: 'Next Slide replaces the slide rather than stacking on it',
        );
      },
    );

    testWithGame<PptxMonstersGame>(
      'a loss is unchanged: no Next Slide',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        arena.player.takeHit(arena.player.health.max);
        advance(game, Player.exitDuration + 0.1);
        await game.ready();

        expect(_labels(_panel(game)), ['Retry Slide', 'Walk Off']);
      },
    );

    testWithGame<PptxMonstersGame>(
      'beating the last built slide shows the normal win panel',
      () => PptxMonstersGame(saveStore: _saved({1})),
      (game) async {
        final last = kLevels.lastWhere((level) => level.isBuilt).number;
        await _win(game, await openArena(game, level: last));

        final panel = _panel(game);
        expect(panel.won, isTrue);
        expect(_labels(panel), ['Retry Slide', 'Walk Off']);
      },
    );
  });

  group('slide sorter', () {
    testWithGame<PptxMonstersGame>(
      'does not open a locked slide',
      PptxMonstersGame.new,
      (game) async {
        final sorter = await _openSorter(game);

        final second = _thumbnail(sorter, 2);
        expect(second.state, SlideState.locked);
        second.select();
        await game.ready();

        expect(game.router.currentRoute.name, Routes.slideSorter);
      },
    );

    testWithGame<PptxMonstersGame>(
      'shows each slide in its state',
      () => PptxMonstersGame(saveStore: _saved({1})),
      (game) async {
        final sorter = await _openSorter(game);

        expect(_thumbnail(sorter, 1).state, SlideState.beaten);
        expect(_thumbnail(sorter, 2).state, SlideState.unlocked);
        for (final level in kLevels.where((level) => !level.isBuilt)) {
          expect(_thumbnail(sorter, level.number).state, SlideState.notBuilt);
        }
      },
    );

    testWithGame<PptxMonstersGame>(
      'marks a slide won from it as soon as the player comes back',
      PptxMonstersGame.new,
      (game) async {
        final sorter = await _openSorter(game);
        _thumbnail(sorter, 1).select();
        await game.ready();

        await _win(game, _arena(game));
        _button(_panel(game), 'Walk Off').onSelected();
        await game.ready();
        advance(game, 1 / 60);

        expect(game.router.currentRoute.name, Routes.slideSorter);
        expect(_thumbnail(sorter, 1).state, SlideState.beaten);
        expect(_thumbnail(sorter, 2).state, SlideState.unlocked);
      },
    );

    testWithGame<PptxMonstersGame>(
      'the unlock-all switch opens every built slide',
      () => PptxMonstersGame(unlockAll: true),
      (game) async {
        final sorter = await _openSorter(game);

        _thumbnail(sorter, 2).select();
        await game.ready();

        expect(_arena(game).level.number, 2);
      },
    );
  });

  group('start menu', () {
    testWithGame<PptxMonstersGame>(
      'continues from the first unbeaten slide',
      () => PptxMonstersGame(saveStore: _saved({1})),
      (game) async {
        final menu = await _started(game);

        final start = _startButton(menu);
        expect(start.label, 'Carry On');
        expect(start.hint, 'Shift+F5');
        expect(_statusLabel(menu), 'Slide 2 of ${kLevels.length}');

        start.onSelected();
        await game.ready();
        expect(_arena(game).level.number, 2);
      },
    );

    testWithGame<PptxMonstersGame>(
      'starts from the beginning once every built slide is won',
      () => PptxMonstersGame(
        saveStore: _saved({
          for (final level in kLevels.where((level) => level.isBuilt))
            level.number,
        }),
      ),
      (game) async {
        final menu = await _started(game);

        final start = _startButton(menu);
        expect(start.label, 'From the Top');
        start.onSelected();
        await game.ready();
        expect(_arena(game).level.number, 1);
      },
    );

    testWithGame<PptxMonstersGame>(
      'catches up with a win when the player comes back',
      PptxMonstersGame.new,
      (game) async {
        final menu = await _started(game);
        expect(_startButton(menu).label, 'Start Presenting');
        expect(_statusLabel(menu), 'Slide 1 of ${kLevels.length}');

        await _win(game, await openArena(game));
        _button(_panel(game), 'Walk Off').onSelected();
        await game.ready();
        advance(game, 1 / 60);
        await game.ready();

        expect(_startButton(menu).label, 'Carry On');
        expect(_statusLabel(menu), 'Slide 2 of ${kLevels.length}');
        expect(
          menu.children.whereType<TextComponent>().map((text) => text.text),
          contains(MainMenuPage.footerLine(kLevels.length - 1)),
        );
      },
    );
  });
}

InMemorySaveStore _saved(Set<int> beaten) =>
    InMemorySaveStore(SaveData(progress: Progress(beaten: beaten)).encode());

Future<MainMenuPage> _started(PptxMonstersGame game) async {
  await game.ready();
  return game.descendants().whereType<MainMenuPage>().single;
}

Future<SlideSorterPage> _openSorter(PptxMonstersGame game) async {
  await game.ready();
  game.router.pushNamed(Routes.slideSorter);
  await game.ready();
  return game.descendants().whereType<SlideSorterPage>().single;
}

Future<void> _win(PptxMonstersGame game, ArenaPage arena) async {
  arena.boss.takeHit(arena.boss.totalHits);
  // The boss plays its exit before the dialog appears.
  advance(game, 0.6);
  await game.ready();
  expect(arena.isResolved, isTrue);
}

ArenaPage _arena(PptxMonstersGame game) =>
    game.router.currentRoute.children.whereType<ArenaPage>().single;

ResultPanel _panel(PptxMonstersGame game) =>
    _arena(game).children.whereType<ResultPanel>().single;

List<String> _labels(ResultPanel panel) =>
    panel.children.whereType<ChipButton>().map((b) => b.label).toList();

ChipButton _button(ResultPanel panel, String label) => panel.children
    .whereType<ChipButton>()
    .singleWhere((button) => button.label == label);

SlideThumbnail _thumbnail(SlideSorterPage sorter, int slide) => sorter.children
    .whereType<SlideThumbnail>()
    .singleWhere((thumbnail) => thumbnail.level.number == slide);

MenuBulletButton _startButton(MainMenuPage menu) => menu.children
    .whereType<MenuBulletButton>()
    .singleWhere((button) => button.position.y < 340);

String _statusLabel(MainMenuPage menu) =>
    menu.children.whereType<StatusBar>().single.slideLabel;
