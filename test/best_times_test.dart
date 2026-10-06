import 'package:death_by_slides/game/components/result_panel.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/levels.dart';
import 'package:death_by_slides/game/pages/arena_page.dart';
import 'package:death_by_slides/game/pages/end_of_show_page.dart';
import 'package:death_by_slides/game/pages/light_table_page.dart';
import 'package:death_by_slides/game/routes.dart';
import 'package:death_by_slides/game/save/save_data.dart';
import 'package:death_by_slides/game/save/save_store.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arena_harness.dart';

InMemorySaveStore _store({
  Set<int> beaten = const {},
  Map<int, SlideTime> times = const {},
  PepTalk pepTalk = const PepTalk(),
}) => InMemorySaveStore(
  SaveData(
    progress: Progress(beaten: beaten, bestTimes: times),
    settings: Settings(pepTalk: pepTalk),
  ).encode(),
);

/// Plays slide [level] for [seconds] of fight, then wins it, and returns the
/// arena with its result decided.
Future<ArenaPage> _winAfter(
  DeathBySlidesGame game,
  double seconds, {
  int level = 1,
}) async {
  final arena = await openArena(game, level: level);
  // Kept in the fight, so a long run is not lost along the way.
  for (var done = 0.0; done < seconds - 1e-9; done += 1) {
    arena.player.health.restore();
    advance(game, seconds - done < 1 ? seconds - done : 1);
  }
  arena.boss.takeHit(arena.boss.totalHits);
  // The boss's exit, which is not on the clock.
  advance(game, 0.6);
  await game.ready();
  expect(arena.isResolved, isTrue);
  return arena;
}

String? _timing(ArenaPage arena) =>
    arena.children.whereType<ResultPanel>().single.timing;

/// Leaves the dialog for the slide underneath.
Future<void> _leave(DeathBySlidesGame game) async {
  game.router.pop();
  await game.ready();
}

void main() {
  group('the rehearsal clock', () {
    testWithGame<DeathBySlidesGame>(
      'runs from the start of the fight to the boss going down',
      () => DeathBySlidesGame(unlockAll: true),
      (game) async {
        final arena = await _winAfter(game, 3);
        // One frame in for the boss's last hits to register.
        expect(arena.clock.elapsed, closeTo(3, 0.05));
        expect(arena.clock.isRunning, isFalse);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'leaves out time spent paused',
      () => DeathBySlidesGame(unlockAll: true),
      (game) async {
        final arena = await openArena(game);
        advance(game, 2);
        arena.pause();
        advance(game, 30);
        arena.resume();
        advance(game, 1);
        expect(arena.clock.elapsed, closeTo(3, 0.05));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'stops on a loss as well, and records nothing',
      () => DeathBySlidesGame(unlockAll: true),
      (game) async {
        final arena = await openArena(game);
        advance(game, 1);
        arena.player.takeHit(arena.player.health.max);
        advance(game, 1);
        await game.ready();
        expect(arena.clock.isRunning, isFalse);
        expect(_timing(arena), isNull);
        expect(game.save.data.progress.bestTimeOf(1), isNull);
      },
    );
  });

  group('best times', () {
    testWithGame<DeathBySlidesGame>(
      'a first win reports its time as a new best',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await _winAfter(game, 42.5);
        expect(_timing(arena), 'Slide time 00:42 · New best');
        expect(
          game.save.data.progress.bestTimeOf(1)!.seconds,
          closeTo(42.5, 0.05),
        );
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a slower run does not replace the best',
      () => DeathBySlidesGame(
        saveStore: _store(beaten: {1}, times: {1: const SlideTime(37.4)}),
      ),
      (game) async {
        final arena = await _winAfter(game, 42.5);
        expect(_timing(arena), 'Slide time 00:42 · Best 00:37');
        expect(game.save.data.progress.bestTimeOf(1)!.seconds, 37.4);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a faster run does, and says so',
      () => DeathBySlidesGame(
        saveStore: _store(beaten: {1}, times: {1: const SlideTime(37.4)}),
      ),
      (game) async {
        final arena = await _winAfter(game, 20.2);
        expect(_timing(arena), 'Slide time 00:20 · New best');
        expect(
          game.save.data.progress.bestTimeOf(1)!.seconds,
          closeTo(20.2, 0.05),
        );
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a run with Pep Talk on is marked, not hidden',
      () => DeathBySlidesGame(
        saveStore: _store(pepTalk: const PepTalk(slowerShots: true)),
      ),
      (game) async {
        final arena = await _winAfter(game, 12);
        expect(_timing(arena), 'Slide time 00:12 (Pep Talk) · New best');
        expect(game.save.data.progress.bestTimeOf(1)!.pepTalk, isTrue);
      },
    );

    final store = InMemorySaveStore();
    testWithGame<DeathBySlidesGame>(
      'times are saved',
      () => DeathBySlidesGame(saveStore: store),
      (game) async {
        await _winAfter(game, 9);
        await game.ready();
        final saved = SaveData.decode(store.document!);
        expect(saved.progress.bestTimeOf(1)!.seconds, closeTo(9, 0.05));
        expect(saved.progress.hasBeaten(1), isTrue);
      },
    );
  });

  group('the light table', () {
    testWithGame<DeathBySlidesGame>(
      'shows a time under beaten slides only',
      () => DeathBySlidesGame(
        unlockAll: true,
        saveStore: _store(
          beaten: {1, 2},
          times: {
            1: const SlideTime(37.4),
            2: const SlideTime(61, pepTalk: true),
          },
        ),
      ),
      (game) async {
        await game.ready();
        game.router.pushNamed(Routes.lightTable);
        await game.ready();
        final thumbnails = {
          for (final thumbnail
              in game.descendants().whereType<SlideThumbnail>())
            thumbnail.level.number: thumbnail,
        };
        expect(thumbnails[1]!.timeText, '00:37');
        expect(thumbnails[2]!.timeText, '01:01 (Pep Talk)');
        for (final slide in [3, 4, 5, 6]) {
          expect(thumbnails[slide]!.timeText, isEmpty, reason: 'slide $slide');
        }
      },
    );

    testWithGame<DeathBySlidesGame>(
      'picks up a new time as soon as the player is back',
      DeathBySlidesGame.new,
      (game) async {
        await game.ready();
        game.router.pushNamed(Routes.lightTable);
        await game.ready();
        await _winAfter(game, 5.5);
        await _leave(game);
        advance(game, 1 / 60);
        final first = game.descendants().whereType<SlideThumbnail>().firstWhere(
          (thumbnail) => thumbnail.level.number == 1,
        );
        expect(first.timeText, '00:05');
      },
    );
  });

  group('the end of the show', () {
    final every = {for (final level in kLevels) level.number};

    testWithGame<DeathBySlidesGame>(
      "reports the last slide's time and the whole deck's",
      () => DeathBySlidesGame(
        saveStore: _store(
          beaten: every.difference({kLevels.last.number}),
          times: {
            for (final level in kLevels.take(kLevels.length - 1))
              level.number: const SlideTime(30),
          },
        ),
      ),
      (game) async {
        await _winAfter(game, 45.5, level: kLevels.last.number);
        advance(game, ArenaPage.endOfShowDelay + 0.05);
        await game.ready();
        expect(game.router.currentRoute.name, Routes.endOfShow);
        final texts = game.descendants().whereType<TextComponent>().map(
          (t) => t.text,
        );
        expect(texts, contains('Slide 6 · Slide time 00:45 · New best'));
        // Five slides at 30 s and this run's 45.5 s.
        expect(texts, contains('Whole deck rehearsed in 03:15'));
      },
    );

    test('has no deck total until every slide has a time', () {
      expect(
        EndOfShowPage.deckTime(
          Progress(beaten: every, bestTimes: {1: const SlideTime(30)}),
        ),
        isNull,
      );
      final all = EndOfShowPage.deckTime(
        Progress(
          beaten: every,
          bestTimes: {
            for (final slide in every)
              slide: SlideTime(10, pepTalk: slide == 3),
          },
        ),
      )!;
      expect(all.seconds, 60);
      expect(all.label, '01:00 (Pep Talk)');
    });
  });

  group('saving times', () {
    test('round-trips, and an old save without times still loads', () {
      final progress = const Progress(
        beaten: {1},
      ).withTime(1, const SlideTime(37.4, pepTalk: true));
      final back = SaveData.decode(
        SaveData(progress: progress).encode(),
      ).progress;
      expect(back.bestTimeOf(1)!.seconds, 37.4);
      expect(back.bestTimeOf(1)!.pepTalk, isTrue);

      final old = SaveData.decode('{"version":1,"progress":{"beaten":[1,2]}}');
      expect(old.progress.beaten, {1, 2});
      expect(old.progress.bestTimes, isEmpty);
    });

    test('an unreadable time is dropped, and the save kept', () {
      final save = SaveData.decode(
        '{"version":1,"progress":{"beaten":[1,2],'
        '"bestTimes":{"1":{"seconds":12.5},"2":{"seconds":"soon"},"x":{"seconds":3}}}}',
      );
      expect(save.progress.beaten, {1, 2});
      expect(save.progress.bestTimes.keys, [1]);
    });

    test('formats times as a rehearsal does', () {
      expect(SlideTime.formatClock(0.4), '00:00');
      expect(SlideTime.formatClock(42.99), '00:42');
      expect(SlideTime.formatClock(61), '01:01');
      expect(SlideTime.formatClock(3725), '62:05');
    });
  });
}
