import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:death_by_slides/game/components/player.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/save/save_data.dart';
import 'package:death_by_slides/game/save/save_file.dart';
import 'package:death_by_slides/game/save/save_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'arena_harness.dart';

void main() {
  group('save file', () {
    test('starts fresh when nothing has been saved', () async {
      final save = await SaveFile.load(InMemorySaveStore());

      expect(save.data.progress.beaten, isEmpty);
    });

    test('reads back, in a new save file, what an earlier one wrote', () async {
      final store = InMemorySaveStore();
      final first = await SaveFile.load(store);
      await first.recordWin(2);
      await first.recordWin(1);

      final second = await SaveFile.load(store);

      expect(second.data.progress.beaten, {1, 2});
    });

    for (final (kind, document) in [
      ('corrupt', '{"version": 1, "progress": {"beaten": [1'),
      ('not a save at all', '[1, 2]'),
      ('from a newer build', '{"version": 2, "progress": {"beaten": [1]}}'),
      ('the wrong shape', '{"version": 1, "progress": {"beaten": ["1"]}}'),
    ]) {
      test(
        'starts fresh from a save that is $kind, without throwing',
        () async {
          final store = InMemorySaveStore(document);

          final save = await SaveFile.load(store);

          expect(save.data.progress.beaten, isEmpty);
          expect(
            store.document,
            document,
            reason: 'left alone until the game next saves',
          );
        },
      );
    }

    test('writes only when something changed', () async {
      final store = _CountingStore();
      final save = await SaveFile.load(store);

      await save.recordWin(1);
      await save.recordWin(1);

      expect(store.writes, 1);
    });

    test('keeps the game going when a write fails', () async {
      final save = await SaveFile.load(_FailingStore());

      await expectLater(save.recordWin(1), completes);
      expect(
        save.data.progress.hasBeaten(1),
        isTrue,
        reason: 'still known for the rest of this run',
      );
    });
  });

  group('shared preferences store', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('reads back what it wrote, from a new store', () async {
      expect(await SharedPreferencesSaveStore().read(), isNull);

      await SharedPreferencesSaveStore().write('{"version": 1}');

      expect(await SharedPreferencesSaveStore().read(), '{"version": 1}');
    });
  });

  group('the game', () {
    final returning = InMemorySaveStore(
      const SaveData(progress: Progress(beaten: {1})).encode(),
    );
    testWithGame<DeathBySlidesGame>(
      'picks up an earlier save when it starts',
      () => DeathBySlidesGame(saveStore: returning),
      (game) async {
        await game.ready();

        expect(game.save.data.progress.hasBeaten(1), isTrue);
      },
    );

    final winning = InMemorySaveStore();
    testWithGame<DeathBySlidesGame>(
      'saves a slide the moment it is won',
      () => DeathBySlidesGame(saveStore: winning),
      (game) async {
        final arena = await openArena(game);

        arena.boss.takeHit(arena.boss.totalHits);
        advance(game, 0.6);
        await game.ready();
        await Future<void>.delayed(Duration.zero);

        expect(arena.isResolved, isTrue);
        expect(game.save.data.progress.hasBeaten(1), isTrue);
        expect(SaveData.decode(winning.document!).progress.beaten, {1});
      },
    );

    final losing = InMemorySaveStore();
    testWithGame<DeathBySlidesGame>(
      'saves nothing for a slide that is lost',
      () => DeathBySlidesGame(saveStore: losing),
      (game) async {
        final arena = await openArena(game);

        arena.player.takeHit(arena.player.health.max);
        // Beating the boss afterwards changes nothing: the slide is lost the
        // moment the player is, even though the exit animation runs first.
        arena.boss.takeHit(arena.boss.totalHits);
        advance(game, Player.exitDuration + 0.2);
        await game.ready();
        await Future<void>.delayed(Duration.zero);

        expect(arena.isResolved, isTrue);
        expect(game.save.data.progress.beaten, isEmpty);
        expect(losing.document, isNull);
      },
    );
  });
}

class _CountingStore extends InMemorySaveStore {
  int writes = 0;

  @override
  Future<void> write(String document) {
    writes++;
    return super.write(document);
  }
}

class _FailingStore implements SaveStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String document) async =>
      throw Exception('disk full, say');
}
