import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';
import 'package:death_by_slides/game/components/autoshape_backdrop.dart';
import 'package:death_by_slides/game/components/shape_actor.dart';
import 'package:death_by_slides/game/input/menu_input.dart';
import 'package:death_by_slides/game/pages/tweaks_page.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/routes.dart';
import 'package:death_by_slides/game/save/save_data.dart';
import 'package:death_by_slides/game/save/save_file.dart';
import 'package:death_by_slides/game/save/save_store.dart';
import 'package:death_by_slides/game/slide/fly_in.dart';
import 'package:death_by_slides/game/slide/motion.dart';
import 'package:death_by_slides/game/slide/slide_metrics.dart';

import 'arena_harness.dart';

/// A game whose save already holds [settings].
DeathBySlidesGame _gameWith(
  Settings settings, {
  bool Function()? deviceReducesMotion,
}) => DeathBySlidesGame(
  saveStore: InMemorySaveStore(SaveData(settings: settings).encode()),
  deviceReducesMotion: deviceReducesMotion,
);

Future<TweaksPage> _openPane(DeathBySlidesGame game) async {
  await game.ready();
  game.router.pushNamed(Routes.tweaks);
  await game.ready();
  return game.router.currentRoute.children.whereType<TweaksPage>().single;
}

final InMemorySaveStore _sharedStore = InMemorySaveStore();

void main() {
  tearDown(() => Motion.reduced = false);

  group('swap sticks', () {
    testWithGame<DeathBySlidesGame>(
      'moves with the right thumb and aims with the left',
      () => _gameWith(const Settings(swapSticks: true)),
      (game) async {
        final arena = await openArena(game);

        expect(arena.moveStick.position.x, greaterThan(_halfSlide));
        expect(arena.aimStick.position.x, lessThan(_halfSlide));
        expect(arena.player.moveStick, same(arena.moveStick));
        expect(arena.player.aimStick, same(arena.aimStick));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'leaves the sticks where they were when off',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);

        expect(arena.moveStick.position.x, lessThan(_halfSlide));
        expect(arena.aimStick.position.x, greaterThan(_halfSlide));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'sizes both sticks from the stick size setting',
      () => _gameWith(const Settings(stickSize: 1.2)),
      (game) async {
        final arena = await openArena(game);

        expect(arena.moveStick.scale, closeToVector(Vector2.all(1.2)));
        expect(arena.aimStick.scale, closeToVector(Vector2.all(1.2)));
      },
    );
  });

  group('dead zone', () {
    testWithGame<DeathBySlidesGame>(
      'reaches the controller input from the slider',
      DeathBySlidesGame.new,
      (game) async {
        final pane = await _openPane(game);

        pane.deadzone.nudge(2);

        expect(game.gamepad.deadzone, closeTo(0.3, 1e-9));
        game.gamepad.handle(stickEvent(GamepadAxis.leftStickX, 0.25));
        expect(
          game.gamepad.move.isZero(),
          isTrue,
          reason: 'inside the new, wider dead zone',
        );
      },
    );

    testWithGame<DeathBySlidesGame>(
      'is read from the save at start-up',
      () => _gameWith(const Settings(deadzone: 0.1)),
      (game) async {
        await game.ready();

        expect(game.gamepad.deadzone, closeTo(0.1, 1e-9));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'stops at the ends of its range',
      DeathBySlidesGame.new,
      (game) async {
        final pane = await _openPane(game);

        pane.deadzone.nudge(100);
        expect(pane.deadzone.value, Settings.maxDeadzone);
        pane.deadzone.nudge(-100);
        expect(pane.deadzone.value, Settings.minDeadzone);
      },
    );
  });

  group('reduce motion', () {
    testWithGame<DeathBySlidesGame>(
      'puts a Fly In element at its destination at once',
      () => _gameWith(const Settings(reduceMotion: true)),
      (game) async {
        await game.ready();
        final shape = PositionComponent(position: Vector2(300, 200));

        shape.flyIn(delay: 0.2);

        expect(shape.position, closeToVector(Vector2(300, 200)));
        expect(shape.children.whereType<MoveEffect>(), isEmpty);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'holds the title slide autoshapes still',
      () => _gameWith(const Settings(reduceMotion: true)),
      (game) async {
        await game.ready();
        final shapes = game.descendants().whereType<FloatingAutoshape>();
        expect(shapes, isNotEmpty);
        final before = [for (final s in shapes) s.position.clone()];

        advance(game, 1);

        expect([for (final s in shapes) s.position], before);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'stops the idle bob, and starts it again when turned off',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        advance(game, 0.1);
        await game.ready();
        final boss = arena.boss.descendants().whereType<ShapeActor>().first;
        expect(boss.descendants().whereType<MoveEffect>(), isNotEmpty);

        game.changeSettings(game.settings.copyWith(reduceMotion: true));
        advance(game, 0.1);
        await game.ready();
        expect(boss.descendants().whereType<MoveEffect>(), isEmpty);

        game.changeSettings(game.settings.copyWith(reduceMotion: false));
        advance(game, 0.1);
        await game.ready();
        expect(boss.descendants().whereType<MoveEffect>(), isNotEmpty);
      },
    );

    testWithGame<DeathBySlidesGame>(
      "follows the device's setting until the player chooses",
      () => DeathBySlidesGame(deviceReducesMotion: () => true),
      (game) async {
        final pane = await _openPane(game);

        expect(Motion.reduced, isTrue);
        expect(pane.reduceMotion.checked, isTrue);

        pane.reduceMotion.activate();

        expect(game.settings.reduceMotion, isFalse);
        expect(Motion.reduced, isFalse, reason: 'the choice beats the device');
      },
    );
  });

  group('the pane', () {
    testWithGame<DeathBySlidesGame>(
      'no longer says the settings do nothing',
      DeathBySlidesGame.new,
      (game) async {
        final pane = await _openPane(game);

        final texts = pane.descendants().whereType<TextComponent>();
        expect(texts.map((t) => t.text), isNot(contains(contains('None of'))));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'can be worked with keys or a controller alone',
      DeathBySlidesGame.new,
      (game) async {
        final pane = await _openPane(game);

        // The first press shows focus, on the first setting.
        game.handleMenuAction(MenuAction.down);
        expect(pane.focused, same(pane.swapSticks));
        game.handleMenuAction(MenuAction.activate);
        expect(game.settings.swapSticks, isTrue);

        game.handleMenuAction(MenuAction.down);
        expect(pane.focused, same(pane.deadzone));
        game.handleMenuAction(MenuAction.right);
        expect(game.settings.deadzone, closeTo(0.25, 1e-9));
        expect(pane.focused, same(pane.deadzone), reason: 'right moved it');

        game.handleMenuAction(MenuAction.down);
        expect(pane.focused, same(pane.stickSize));
        game.handleMenuAction(MenuAction.left);
        expect(game.settings.stickSize, closeTo(0.95, 1e-9));

        game.handleMenuAction(MenuAction.up);
        game.handleMenuAction(MenuAction.up);
        game.handleMenuAction(MenuAction.right);
        expect(pane.focused, same(pane.reduceMotion));
        game.handleMenuAction(MenuAction.activate);
        expect(Motion.reduced, isTrue);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'shows each setting as saved',
      () => _gameWith(
        const Settings(swapSticks: true, deadzone: 0.35, stickSize: 0.8),
      ),
      (game) async {
        final pane = await _openPane(game);

        expect(pane.swapSticks.checked, isTrue);
        expect(pane.deadzone.value, closeTo(0.35, 1e-9));
        expect(pane.stickSize.value, closeTo(0.8, 1e-9));
        expect(
          pane.deadzone.descendants().whereType<TextComponent>().map(
            (t) => t.text,
          ),
          contains('35%'),
        );
      },
    );
  });

  group('the slider, by touch', () {
    testWidgets('jumps to a tap on the track, and steps on minus and plus', (
      tester,
    ) async {
      final game = DeathBySlidesGame();
      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump(const Duration(milliseconds: 100));
      game.router.pushNamed(Routes.tweaks);
      // Past the last fly-in, so the slider is where it is drawn.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final pane = game.router.currentRoute.children
          .whereType<TweaksPage>()
          .single;
      final slider = pane.deadzone;
      Offset at(double x) {
        final point = slider.absolutePositionOf(Vector2(x, slider.height / 2));
        return Offset(point.x, point.y);
      }

      // The track runs from 290 to 110 units short of the row's right end.
      await tester.tapAt(at(slider.width - 290 + 20));
      await tester.pump();
      expect(slider.value, closeTo(0.1, 1e-9));
      expect(game.settings.deadzone, closeTo(0.1, 1e-9));

      await tester.tapAt(at(slider.width - 110 + 24));
      await tester.pump();
      expect(slider.value, closeTo(0.15, 1e-9));

      await tester.tapAt(at(slider.width - 290 - 24));
      await tester.pump();
      expect(slider.value, closeTo(0.1, 1e-9));
      // Lets the gesture recognisers' own timers run out.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('saving', () {
    testWithGame<DeathBySlidesGame>(
      'settings survive a new game instance',
      () => DeathBySlidesGame(saveStore: _sharedStore),
      (game) async {
        await game.ready();
        game.changeSettings(
          const Settings(
            swapSticks: true,
            deadzone: 0.3,
            stickSize: 1.1,
            reduceMotion: true,
          ),
        );
        // The write is on its way, not awaited by the pane.
        await Future<void>.delayed(Duration.zero);
        Motion.reduced = false;

        final next = await initializeGame(
          () => DeathBySlidesGame(saveStore: _sharedStore),
        );

        final settings = next.settings;
        expect(settings.swapSticks, isTrue);
        expect(settings.deadzone, closeTo(0.3, 1e-9));
        expect(settings.stickSize, closeTo(1.1, 1e-9));
        expect(settings.reduceMotion, isTrue);
        expect(next.gamepad.deadzone, closeTo(0.3, 1e-9));
        expect(Motion.reduced, isTrue, reason: 'applied as the game loads');
      },
    );

    test('a save from before settings existed loads the defaults', () {
      final data = SaveData.decode(
        '{"version": 1, "progress": {"beaten": [1]}}',
      );

      expect(data.progress.beaten, {1});
      expect(data.settings.swapSticks, isFalse);
      expect(data.settings.deadzone, Settings.defaultDeadzone);
      expect(data.settings.reduceMotion, isNull);
    });

    test('keeps the progress when settings change', () async {
      final store = InMemorySaveStore();
      final save = await SaveFile.load(store);
      await save.recordWin(1);
      await save.updateSettings(const Settings(swapSticks: true));

      final again = await SaveFile.load(store);

      expect(again.data.progress.beaten, {1});
      expect(again.data.settings.swapSticks, isTrue);
    });

    test('pulls a dead zone from outside the slider back into range', () {
      final settings = Settings.fromJson({'deadzone': 0.9, 'stickSize': 0.1});

      expect(settings.deadzone, Settings.maxDeadzone);
      expect(settings.stickSize, Settings.minStickSize);
    });

    test('starts fresh from settings of the wrong shape', () async {
      final store = InMemorySaveStore(
        '{"version": 1, "settings": {"swapSticks": "yes"}}',
      );

      final save = await SaveFile.load(store);

      expect(save.data.settings.swapSticks, isFalse);
    });
  });
}

const double _halfSlide = kSlideWidth / 2;
