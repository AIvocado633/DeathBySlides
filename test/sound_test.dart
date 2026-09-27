import 'dart:convert';

import 'package:death_by_slides/game/audio/game_audio.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/pages/tweaks_page.dart';
import 'package:death_by_slides/game/routes.dart';
import 'package:death_by_slides/game/save/save_data.dart';
import 'package:death_by_slides/game/save/save_store.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

import 'arena_harness.dart';
import 'fake_audio.dart';

/// A game that plays into [backend], starting from [settings] if given.
DeathBySlidesGame Function() _gameWith(
  RecordingAudioBackend backend, {
  Settings? settings,
}) => () => DeathBySlidesGame(
  audioBackend: backend,
  saveStore: settings == null
      ? null
      : InMemorySaveStore(SaveData(settings: settings).encode()),
);

/// One frame, so the game hands the page on top's music to the audio.
void _frame(DeathBySlidesGame game) => advance(game, 1 / 60);

void main() {
  group('effects', () {
    final backend = RecordingAudioBackend();
    setUp(backend.clear);

    testWithGame<DeathBySlidesGame>(
      'firing plays a click',
      _gameWith(backend),
      (game) async {
        final arena = await openArena(game);
        backend.clear();

        arena.player.fire();

        expect(backend.played(Cue.bulletPoint), 1);
        expect(
          backend.effects.single.volume,
          Settings.defaultEffectsVolume,
          reason: 'played at the effects volume from Tweaks',
        );
      },
    );

    testWithGame<DeathBySlidesGame>(
      'caps how many clicks sound at once',
      _gameWith(backend),
      (game) async {
        final arena = await openArena(game);
        backend.clear();

        for (var i = 0; i < 10; i++) {
          arena.player.fire();
        }
        expect(backend.played(Cue.bulletPoint), Cue.bulletPoint.maxVoices);

        // Once the first clicks have finished, there is room again.
        advance(game, Cue.bulletPoint.length);
        arena.player.fire();
        expect(backend.played(Cue.bulletPoint), Cue.bulletPoint.maxVoices + 1);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a fight opens with a drum roll, and loads its effects first',
      _gameWith(backend),
      (game) async {
        final arena = await openArena(game);

        expect(backend.played(Cue.drumRoll), 1);
        for (final cue in [Cue.bulletPoint, Cue.applause, ...arena.boss.cues]) {
          expect(backend.loaded, contains(cue.file), reason: '$cue');
        }
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a win plays applause',
      _gameWith(backend),
      (game) async {
        final arena = await openArena(game);

        arena.boss.takeHit(arena.boss.remainingHits);
        advance(game, 1);
        await game.ready();

        expect(arena.isResolved, isTrue);
        expect(backend.played(Cue.shrinkToFitDefeated), 1);
        expect(backend.played(Cue.applause), 1);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a loss plays something deflating, and no applause',
      _gameWith(backend),
      (game) async {
        final arena = await openArena(game);

        arena.player.takeHit(arena.player.health.current);
        advance(game, 1);
        await game.ready();

        expect(arena.isResolved, isTrue);
        expect(backend.played(Cue.playerLost), 1);
        expect(backend.played(Cue.applause), 0);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'each boss has its own hit sound',
      _gameWith(backend),
      (game) async {
        final autoFit = await openArena(game);
        autoFit.boss.takeHit();
        expect(backend.played(Cue.shrinkToFitHit), 1);

        game.router.pop();
        await game.ready();
        final diagram = await openArena(game, level: 2);
        diagram.boss.takeHit();
        expect(backend.played(Cue.diagramHit), 1);
        // A second hit breaks the shape, and the survivors re-lay themselves.
        diagram.boss.takeHit();
        expect(backend.played(Cue.diagramShapeBroken), 1);
        expect(backend.played(Cue.diagramReflow), 1);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'pages whoosh in, unless motion is reduced',
      () => DeathBySlidesGame(
        audioBackend: backend,
        deviceReducesMotion: () => true,
      ),
      (game) async {
        await game.ready();
        game.router.pushNamed(Routes.lightTable);
        await game.ready();

        expect(backend.played(Cue.whoosh), 0);
      },
    );
  });

  group('music', () {
    final backend = RecordingAudioBackend();
    setUp(backend.clear);

    testWithGame<DeathBySlidesGame>(
      'menus play the menu loop, a fight the fight loop, and back again',
      _gameWith(backend),
      (game) async {
        await game.ready();
        _frame(game);
        expect(backend.looping, Track.menu.file);

        await openArena(game);
        _frame(game);
        expect(backend.looping, Track.fight.file);

        game.router.pop();
        await game.ready();
        _frame(game);
        expect(backend.looping, Track.menu.file);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'pausing the fight pauses the music, and resuming picks it up',
      _gameWith(backend),
      (game) async {
        final arena = await openArena(game);
        _frame(game);

        arena.pause();
        expect(backend.isPaused, isTrue);

        arena.resume();
        expect(backend.isPaused, isFalse);
        expect(backend.looping, Track.fight.file, reason: 'the same loop');
      },
    );

    testWithGame<DeathBySlidesGame>(
      'walking off a paused fight lets the menu music play',
      _gameWith(backend),
      (game) async {
        final arena = await openArena(game);
        _frame(game);
        arena.pause();

        game.router.pop();
        await game.ready();
        _frame(game);

        expect(backend.looping, Track.menu.file);
        expect(backend.isPaused, isFalse);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'music holds while the app is away',
      _gameWith(backend),
      (game) async {
        await game.ready();
        _frame(game);

        game.lifecycleStateChange(AppLifecycleState.paused);
        expect(backend.isPaused, isTrue);

        game.lifecycleStateChange(AppLifecycleState.resumed);
        expect(backend.isPaused, isFalse);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a fight that paused itself in the background stays quiet on return',
      _gameWith(backend),
      (game) async {
        final arena = await openArena(game);
        _frame(game);

        game.lifecycleStateChange(AppLifecycleState.paused);
        game.lifecycleStateChange(AppLifecycleState.resumed);

        expect(arena.isPaused, isTrue);
        expect(backend.isPaused, isTrue);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a decided slide stops the fight music',
      _gameWith(backend),
      (game) async {
        final arena = await openArena(game);
        _frame(game);

        arena.boss.takeHit(arena.boss.remainingHits);
        advance(game, 1);
        await game.ready();
        _frame(game);

        expect(backend.looping, isNull);
      },
    );
  });

  group('volume', () {
    final backend = RecordingAudioBackend();
    setUp(backend.clear);

    testWithGame<DeathBySlidesGame>(
      'at zero, nothing is loaded or played',
      _gameWith(
        backend,
        settings: const Settings(musicVolume: 0, effectsVolume: 0),
      ),
      (game) async {
        final arena = await openArena(game);
        _frame(game);
        arena.player.fire();
        arena.boss.takeHit(arena.boss.remainingHits);
        advance(game, 1);

        expect(backend.loaded, isEmpty);
        expect(backend.effects, isEmpty);
        expect(backend.music, isEmpty);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'turning the music off stops it, and on again starts it',
      _gameWith(backend),
      (game) async {
        await game.ready();
        _frame(game);

        game.changeSettings(game.settings.copyWith(musicVolume: 0));
        expect(backend.looping, isNull);

        game.changeSettings(game.settings.copyWith(musicVolume: 0.3));
        expect(backend.looping, Track.menu.file);
      },
    );

    final store = InMemorySaveStore();
    testWithGame<DeathBySlidesGame>(
      'the Tweaks sliders save the volumes and preview the effects',
      () => DeathBySlidesGame(audioBackend: backend, saveStore: store),
      (game) async {
        await game.ready();
        game.router.pushNamed(Routes.tweaks);
        await game.ready();
        final page = game.router.currentRoute.children
            .whereType<TweaksPage>()
            .single;
        backend.clear();

        page.effectsVolume.nudge(-3);
        page.musicVolume.nudge(1);

        expect(game.settings.effectsVolume, closeTo(0.5, 1e-9));
        expect(game.settings.musicVolume, closeTo(0.6, 1e-9));
        expect(backend.effects.last.file, Cue.bulletPoint.file);
        expect(backend.effects.last.volume, closeTo(0.5, 1e-9));

        await Future<void>.delayed(Duration.zero);
        final saved = SaveData.decode(store.document!).settings;
        expect(saved.effectsVolume, closeTo(0.5, 1e-9));
        expect(saved.musicVolume, closeTo(0.6, 1e-9));
      },
    );
  });

  group('settings', () {
    test('volumes default to music under the effects', () {
      const settings = Settings();
      expect(settings.musicVolume, Settings.defaultMusicVolume);
      expect(settings.effectsVolume, Settings.defaultEffectsVolume);
      expect(settings.musicVolume, lessThan(settings.effectsVolume));
    });

    test('volumes survive a save, and are pulled back into 0-1', () {
      const settings = Settings(musicVolume: 0.3, effectsVolume: 0);
      final back = Settings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())),
      );
      expect(back.musicVolume, 0.3);
      expect(back.effectsVolume, 0);

      final wild = Settings.fromJson({'musicVolume': 7, 'effectsVolume': -1});
      expect(wild.musicVolume, 1);
      expect(wild.effectsVolume, 0);
    });

    test('an older save without volumes gets the defaults', () {
      final old = Settings.fromJson({'swapSticks': true});
      expect(old.musicVolume, Settings.defaultMusicVolume);
      expect(old.effectsVolume, Settings.defaultEffectsVolume);
    });
  });

  group('GameAudio', () {
    test('effects turned up after starting at zero load on first play', () {
      final backend = RecordingAudioBackend();
      final audio = GameAudio(backend)
        ..setVolumes(music: 0, effects: 0)
        ..preload(Cue.values);
      expect(backend.loaded, isEmpty);

      audio
        ..setVolumes(music: 0, effects: 1)
        ..play(Cue.applause);
      expect(backend.loaded, [Cue.applause.file]);
      expect(backend.played(Cue.applause), 1);
    });
  });
}
