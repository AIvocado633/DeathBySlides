import 'package:death_by_slides/game/components/chip_button.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/input/menu_input.dart';
import 'package:death_by_slides/game/pages/intro_page.dart';
import 'package:death_by_slides/game/pages/main_menu_page.dart';
import 'package:death_by_slides/game/routes.dart';
import 'package:death_by_slides/game/save/save_data.dart';
import 'package:death_by_slides/game/save/save_store.dart';
import 'package:death_by_slides/game/slide/motion.dart';
import 'package:flame/effects.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arena_harness.dart';

DeathBySlidesGame _launch([InMemorySaveStore? store]) =>
    DeathBySlidesGame(showIntro: true, saveStore: store);

Future<IntroPage> _intro(DeathBySlidesGame game) async {
  await game.ready();
  expect(game.router.currentRoute.name, Routes.intro);
  return game.router.currentRoute.children.whereType<IntroPage>().single;
}

/// Runs the intro on, frame by frame, settling new components as it goes.
Future<void> _play(DeathBySlidesGame game, double seconds) async {
  for (var done = 0.0; done < seconds - 1e-9; done += 0.5) {
    advance(game, seconds - done < 0.5 ? seconds - done : 0.5);
    await game.ready();
  }
}

Future<void> _onTitleSlide(DeathBySlidesGame game) async {
  await game.ready();
  advance(game, 1 / 60);
  await game.ready();
  expect(game.router.currentRoute.name, Routes.normalView);
}

void main() {
  tearDown(() => Motion.reduced = false);

  group('the intro', () {
    testWithGame<DeathBySlidesGame>('plays on a first launch', _launch, (
      game,
    ) async {
      final intro = await _intro(game);
      expect(intro.scene, 0);
      expect(intro.caption, contains('11:58 PM'));
    });

    testWithGame<DeathBySlidesGame>(
      'is left out unless the app asks for it, as in every other test',
      DeathBySlidesGame.new,
      (game) async {
        await _onTitleSlide(game);
      },
    );

    final store = InMemorySaveStore();
    testWithGame<DeathBySlidesGame>(
      'runs through its five scenes onto the title slide, and is saved seen',
      () => _launch(store),
      (game) async {
        final intro = await _intro(game);
        final scenes = <int>{};
        final captions = <String>{};
        for (var t = 0.0; t < IntroPage.length - 0.5; t += 0.5) {
          await _play(game, 0.5);
          scenes.add(intro.scene);
          captions.add(intro.caption);
        }
        expect(scenes, {0, 1, 2, 3, 4});
        expect(
          captions,
          containsAll([
            'Shrink-to-Fit had other ideas.',
            'So did the Diagram Wizard.',
            'And the Master Template.',
            'Then it turned out the deck was last saved in 2003.',
            'There was only one way to finish this deck.',
          ]),
        );

        await _play(game, 1);
        await _onTitleSlide(game);
        expect(game.save.data.introSeen, isTrue);
        expect(SaveData.decode(store.document!).introSeen, isTrue);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'plays once: a save that has seen it starts on the title slide',
      () =>
          _launch(InMemorySaveStore(const SaveData(introSeen: true).encode())),
      (game) async {
        await _onTitleSlide(game);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'Skip ends it at once, and counts as seen',
      _launch,
      (game) async {
        final intro = await _intro(game);
        intro
            .descendants()
            .whereType<ChipButton>()
            .singleWhere((chip) => chip.label == 'Skip')
            .onSelected();
        await _onTitleSlide(game);
        expect(game.save.data.introSeen, isTrue);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'any key skips it, but not in its first second',
      _launch,
      (game) async {
        await _intro(game);
        void press(LogicalKeyboardKey key, PhysicalKeyboardKey physical) =>
            game.onKeyEvent(
              KeyDownEvent(
                physicalKey: physical,
                logicalKey: key,
                timeStamp: Duration.zero,
              ),
              {key},
            );

        press(LogicalKeyboardKey.keyQ, PhysicalKeyboardKey.keyQ);
        await game.ready();
        expect(
          game.router.currentRoute.name,
          Routes.intro,
          reason: 'the press that launched the game is not a skip',
        );

        await _play(game, IntroPage.skipDelay);
        press(LogicalKeyboardKey.keyQ, PhysicalKeyboardKey.keyQ);
        await _onTitleSlide(game);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'arrows only move focus to Skip; Enter then skips',
      _launch,
      (game) async {
        final intro = await _intro(game);
        await _play(game, IntroPage.skipDelay);
        game
          ..handleMenuAction(MenuAction.down)
          ..handleMenuAction(MenuAction.down);
        await game.ready();
        expect(game.router.currentRoute.name, Routes.intro);
        expect((intro.focused! as ChipButton).label, 'Skip');
        game.handleMenuAction(MenuAction.activate);
        await _onTitleSlide(game);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'can be watched again from the title slide',
      () =>
          _launch(InMemorySaveStore(const SaveData(introSeen: true).encode())),
      (game) async {
        await _onTitleSlide(game);
        final menu = game.descendants().whereType<MainMenuPage>().single;
        menu
            .descendants()
            .whereType<ChipButton>()
            .singleWhere((chip) => chip.label == 'The Night Before')
            .onSelected();
        final intro = await _intro(game);
        expect(intro.scene, 0);
        await _play(game, IntroPage.length + 0.5);
        await _onTitleSlide(game);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'with Reduce Motion, keeps time but nothing moves',
      () {
        Motion.reduced = true;
        return _launch(
          InMemorySaveStore(
            SaveData(settings: const Settings(reduceMotion: true)).encode(),
          ),
        );
      },
      (game) async {
        final intro = await _intro(game);
        for (var t = 0.0; t < IntroPage.length - 0.5; t += 0.5) {
          await _play(game, 0.5);
          final moving = intro.descendants().whereType<Effect>().where(
            (effect) =>
                effect is MoveEffect ||
                effect is ScaleEffect ||
                effect is OpacityEffect,
          );
          expect(moving, isEmpty, reason: 'at ${intro.elapsed}s');
        }
        await _play(game, 1);
        await _onTitleSlide(game);
      },
    );
  });

  group('the save', () {
    test('remembers the intro was seen, and an old save has not', () {
      const seen = SaveData(introSeen: true);
      expect(SaveData.decode(seen.encode()).introSeen, isTrue);
      expect(
        SaveData.decode('{"version":1,"progress":{"beaten":[]}}').introSeen,
        isFalse,
      );
    });
  });
}
