import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:death_by_slides/game/components/menu_bullet_button.dart';
import 'package:death_by_slides/game/pages/tweaks_page.dart';
import 'package:death_by_slides/game/pages/main_menu_page.dart';
import 'package:death_by_slides/game/pages/light_table_page.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/routes.dart';
import 'package:death_by_slides/game/slide/slide_metrics.dart';

import 'arena_harness.dart';

void main() {
  group('start menu', () {
    testWithGame<DeathBySlidesGame>(
      'opens on the main menu slide',
      DeathBySlidesGame.new,
      (game) async {
        await game.ready();

        expect(game.router.currentRoute.name, Routes.normalView);
        expect(game.descendants().whereType<MainMenuPage>().length, 1);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'lists the menu entries in order',
      DeathBySlidesGame.new,
      (game) async {
        await game.ready();

        final labels = game
            .descendants()
            .whereType<MenuBulletButton>()
            .map((button) => button.label)
            .toList();
        expect(labels, ['Start Presenting', 'Light Table', 'Tweaks']);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'letterboxes the 16:9 slide inside a 4:3 window',
      DeathBySlidesGame.new,
      (game) async {
        await game.ready();

        // flame_test sizes the game at 800x600, so the slide is width-bound.
        final page = game.descendants().whereType<MainMenuPage>().single;
        const expectedScale = 800 / kSlideWidth;
        expect(page.scale.x, closeTo(expectedScale, 1e-9));
        expect(page.position.x, closeTo(0, 1e-9));
        expect(
          page.position.y,
          closeTo((600 - kSlideHeight * expectedScale) / 2, 1e-9),
        );
      },
    );
  });

  group('entrance animation', () {
    testWithGame<DeathBySlidesGame>(
      'settles every menu element at its designed slide position',
      DeathBySlidesGame.new,
      (game) async {
        await game.ready();
        // Three seconds is comfortably past the last staggered fly-in.
        advance(game, 3);
        await game.ready();

        final buttons = game.descendants().whereType<MenuBulletButton>();
        for (final (index, button) in buttons.indexed) {
          expect(
            button.position,
            closeToVector(Vector2(76, 336 + index * 78), 0.01),
          );
        }
      },
    );

    testWithGame<DeathBySlidesGame>(
      'leaves nothing hanging off the edge of the slide',
      DeathBySlidesGame.new,
      (game) async {
        await game.ready();
        advance(game, 3);
        await game.ready();

        final page = game.descendants().whereType<MainMenuPage>().single;
        for (final child in page.children.whereType<PositionComponent>()) {
          final bounds = child.toRect();
          expect(
            bounds.left,
            greaterThanOrEqualTo(-2),
            reason: '\${child.runtimeType} starts off the left of the slide',
          );
          expect(
            bounds.right,
            lessThanOrEqualTo(kSlideWidth + 2),
            reason: '\${child.runtimeType} runs off the right of the slide',
          );
        }
      },
    );
  });

  group('navigation', () {
    testWithGame<DeathBySlidesGame>(
      'pushes the light table and pops back to the menu',
      DeathBySlidesGame.new,
      (game) async {
        await game.ready();

        game.router.pushNamed(Routes.lightTable);
        await game.ready();
        expect(game.router.currentRoute.name, Routes.lightTable);
        expect(game.descendants().whereType<LightTablePage>().length, 1);

        game.router.pop();
        await game.ready();
        expect(game.router.currentRoute.name, Routes.normalView);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'pushes the tweaks panel',
      DeathBySlidesGame.new,
      (game) async {
        await game.ready();

        game.router.pushNamed(Routes.tweaks);
        await game.ready();
        expect(game.descendants().whereType<TweaksPage>().length, 1);
      },
    );
  });
}
