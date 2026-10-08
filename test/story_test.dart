import 'package:death_by_slides/game/components/chip_button.dart';
import 'package:death_by_slides/game/components/result_panel.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/levels.dart';
import 'package:death_by_slides/game/pages/arena_page.dart';
import 'package:death_by_slides/game/pages/intro_page.dart';
import 'package:death_by_slides/game/pages/main_menu_page.dart';
import 'package:death_by_slides/game/pages/story_page.dart';
import 'package:death_by_slides/game/routes.dart';
import 'package:death_by_slides/game/save/save_data.dart';
import 'package:death_by_slides/game/save/save_store.dart';
import 'package:death_by_slides/game/slide/motion.dart';
import 'package:flame/effects.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arena_harness.dart';

/// A game that tells the story, with the intro already seen.
DeathBySlidesGame _game({
  Set<int> beaten = const {},
  Set<int> seen = const {},
  bool reduceMotion = false,
  InMemorySaveStore? store,
}) => DeathBySlidesGame(
  tellStory: true,
  saveStore:
      store ??
      InMemorySaveStore(
        SaveData(
          progress: Progress(beaten: beaten),
          introSeen: true,
          storiesSeen: seen,
          settings: Settings(reduceMotion: reduceMotion ? true : null),
        ).encode(),
      ),
);

String _route(DeathBySlidesGame game) => game.router.currentRoute.name!;

T _page<T>(DeathBySlidesGame game) =>
    game.router.currentRoute.children.whereType<T>().single;

Future<void> _settle(DeathBySlidesGame game) async {
  await game.ready();
  advance(game, 1 / 60);
  await game.ready();
}

/// Runs a scene on, settling what it adds as it goes, and records every
/// caption it shows.
Future<Set<String>> _watch(DeathBySlidesGame game, double seconds) async {
  final captions = <String>{};
  for (var t = 0.0; t < seconds - 1e-9; t += 0.25) {
    advance(game, 0.25);
    await game.ready();
    final scene = game.router.currentRoute.children
        .whereType<StoryPage>()
        .firstOrNull;
    if (scene != null) {
      captions.add(scene.caption);
    }
  }
  return captions;
}

/// Wins the slide being fought and chooses Next Slide.
Future<void> _winAndGoOn(DeathBySlidesGame game) async {
  final arena = _page<ArenaPage>(game);
  arena.boss.takeHit(arena.boss.totalHits);
  advance(game, 0.6);
  await game.ready();
  arena.children
      .whereType<ResultPanel>()
      .single
      .children
      .whereType<ChipButton>()
      .singleWhere((b) => b.label == 'Next Slide')
      .onSelected();
  await _settle(game);
}

void main() {
  tearDown(() => Motion.reduced = false);

  group('the scenes between slides', () {
    testWithGame<DeathBySlidesGame>(
      'Next Slide plays the scene first, then the fight',
      _game,
      (game) async {
        game.presentSlide(1);
        await _settle(game);
        expect(
          _route(game),
          Routes.slideShowFor(1),
          reason: 'no scene before 1',
        );

        await _winAndGoOn(game);
        expect(_route(game), Routes.storyAfter(1));
        expect(_page<StoryPage>(game).caption, StoryPage.scenes[1]!.opening);

        await _watch(game, StoryPage.sceneLength + 0.5);
        await _settle(game);
        expect(_route(game), Routes.slideShowFor(2));
        expect(game.save.data.storiesSeen, {1});
      },
    );

    testWithGame<DeathBySlidesGame>(
      'plays once: the next time, straight into the fight',
      () => _game(beaten: {1}, seen: {1}),
      (game) async {
        game.presentSlide(2);
        await _settle(game);
        expect(_route(game), Routes.slideShowFor(2));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the light table plays it too, for a slide reached any other way',
      () => _game(beaten: {1, 2}),
      (game) async {
        game.router.pushNamed(Routes.lightTable);
        await _settle(game);
        game.presentSlide(3);
        await _settle(game);
        expect(_route(game), Routes.storyAfter(2));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'Skip goes straight to the fight, and counts as seen',
      () => _game(beaten: {1}),
      (game) async {
        game.presentSlide(2);
        await _settle(game);
        _page<StoryPage>(game).finish(skipping: true);
        await _settle(game);
        expect(_route(game), Routes.slideShowFor(2));
        expect(game.save.data.storiesSeen, {1});
      },
    );

    testWithGame<DeathBySlidesGame>(
      'retrying a slide never plays a scene',
      () => _game(beaten: {1}, seen: {1}),
      (game) async {
        game.presentSlide(2);
        await _settle(game);
        final arena = _page<ArenaPage>(game);
        arena.player.takeHit(arena.player.health.max);
        advance(game, 1);
        await game.ready();
        arena.children
            .whereType<ResultPanel>()
            .single
            .children
            .whereType<ChipButton>()
            .singleWhere((b) => b.label == 'Retry Slide')
            .onSelected();
        await _settle(game);
        expect(_route(game), Routes.slideShowFor(2));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the last win plays the morning before the end of the show',
      () => _game(
        beaten: {for (final l in kLevels) l.number}..remove(6),
        seen: {1, 2, 3, 4, 5},
      ),
      (game) async {
        game.presentSlide(6);
        await _settle(game);
        final arena = _page<ArenaPage>(game);
        arena.boss.takeHit(arena.boss.totalHits);
        advance(game, 0.6 + ArenaPage.endOfShowDelay + 0.05);
        await _settle(game);
        expect(_route(game), Routes.storyAfter(6));

        final captions = await _watch(game, StoryPage.sceneLength + 0.5);
        expect(captions, contains('And the slides, for once, behave.'));
        await _settle(game);
        expect(_route(game), Routes.endOfShow);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'without the story told, slides open as they always did',
      () => DeathBySlidesGame(
        saveStore: InMemorySaveStore(
          const SaveData(progress: Progress(beaten: {1})).encode(),
        ),
      ),
      (game) async {
        await game.ready();
        game.presentSlide(2);
        await _settle(game);
        expect(_route(game), Routes.slideShowFor(2));
      },
    );
  });

  group('every scene', () {
    for (final after in StoryPage.scenes.keys) {
      testWithGame<DeathBySlidesGame>(
        'after slide $after plays through its beats onto what follows',
        () => _game(beaten: {for (var s = 1; s <= after; s++) s}),
        (game) async {
          if (after == kLevels.last.number) {
            game.presentEnding();
          } else {
            game.presentSlide(after + 1);
          }
          await _settle(game);
          expect(_route(game), Routes.storyAfter(after));
          final captions = await _watch(game, StoryPage.sceneLength + 0.5);
          expect(captions, contains(StoryPage.scenes[after]!.opening));
          expect(captions.length, greaterThanOrEqualTo(3), reason: '$captions');
          await _settle(game);
          expect(game.save.data.storiesSeen, contains(after));
          expect(Routes.isCutscene(_route(game)), isFalse);
        },
      );

      testWithGame<DeathBySlidesGame>(
        'after slide $after, with Reduce Motion, nothing moves',
        () => _game(
          beaten: {for (var s = 1; s <= after; s++) s},
          reduceMotion: true,
        ),
        (game) async {
          game.router.pushNamed(Routes.storyAfter(after));
          await _settle(game);
          final scene = _page<StoryPage>(game);
          for (var t = 0.0; t < StoryPage.sceneLength - 0.25; t += 0.25) {
            advance(game, 0.25);
            await game.ready();
            expect(
              scene.descendants().whereType<Effect>().where(
                (e) =>
                    e is MoveEffect || e is ScaleEffect || e is OpacityEffect,
              ),
              isEmpty,
              reason: 'at ${scene.elapsed}s',
            );
          }
        },
      );
    }
  });

  group('the story so far', () {
    testWithGame<DeathBySlidesGame>(
      'The Night Before plays the intro, then every scene seen',
      () => _game(beaten: {1, 2, 3}, seen: {1, 2}),
      (game) async {
        await _settle(game);
        _page<MainMenuPage>(game)
            .descendants()
            .whereType<ChipButton>()
            .singleWhere((chip) => chip.label == 'The Night Before')
            .onSelected();
        await _settle(game);
        expect(_route(game), Routes.intro);

        await _watch(game, IntroPage.totalLength + 0.5);
        await _settle(game);
        expect(_route(game), Routes.storyAfter(1));
        await _watch(game, StoryPage.sceneLength + 0.5);
        await _settle(game);
        expect(_route(game), Routes.storyAfter(2));
        await _watch(game, StoryPage.sceneLength + 0.5);
        await _settle(game);
        expect(_route(game), Routes.normalView);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'Skip skips the rest of the story too',
      () => _game(beaten: {1, 2, 3}, seen: {1, 2}),
      (game) async {
        await _settle(game);
        game.watchStory();
        await _settle(game);
        _page<IntroPage>(game).finish(skipping: true);
        await _settle(game);
        expect(_route(game), Routes.normalView);
      },
    );
  });

  test('the save remembers the scenes seen, and shrugs off nonsense', () {
    const save = SaveData(storiesSeen: {1, 3});
    expect(SaveData.decode(save.encode()).storiesSeen, {1, 3});
    expect(
      SaveData.decode(
        '{"version":1,"progress":{"beaten":[]},"storiesSeen":"lots"}',
      ).storiesSeen,
      isEmpty,
    );
  });
}
