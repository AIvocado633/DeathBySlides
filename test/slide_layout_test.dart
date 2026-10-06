import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:death_by_slides/game/components/autoshape_backdrop.dart';
import 'package:death_by_slides/game/components/toolbar.dart';
import 'package:death_by_slides/game/components/status_bar.dart';
import 'package:death_by_slides/game/levels.dart';
import 'package:death_by_slides/game/pages/light_table_page.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/routes.dart';
import 'package:death_by_slides/game/slide/slide_metrics.dart';

import 'arena_harness.dart';
import 'package:death_by_slides/game/slide/slide_page.dart';

/// Layout guard rails.
///
/// Every page lays itself out in slide units, so sizing the game to exactly one
/// slide makes absolute component positions read as slide coordinates. Anything
/// that escapes the slide, or wanders into the toolbar or status bar, is a bug.
///
/// This catches the failure mode that bit the first pass: an entrance animation
/// that never settles leaves its element parked off the edge of the slide.
/// Sibling overlap is not covered -- plenty of it is intentional -- so that
/// still needs an eye on the running game.
void main() {
  for (final route in [
    Routes.normalView,
    Routes.lightTable,
    Routes.tweaks,
    Routes.pepTalk,
    Routes.endOfShow,
    // Every playable level, so a new boss cannot quietly overflow a slide.
    for (final level in kLevels.where((level) => level.isBuilt))
      Routes.slideShowFor(level.number),
  ]) {
    group(route, () {
      testWithGame<DeathBySlidesGame>(
        'keeps every element on the slide',
        DeathBySlidesGame.new,
        (game) async {
          final page = await settle(game, route);

          for (final component in contentOf(page)) {
            final bounds = absoluteRect(component);
            expect(
              bounds.left,
              greaterThanOrEqualTo(-2),
              reason: '${component.runtimeType} hangs off the left',
            );
            expect(
              bounds.right,
              lessThanOrEqualTo(kSlideWidth + 2),
              reason: '${component.runtimeType} hangs off the right',
            );
            expect(
              bounds.top,
              greaterThanOrEqualTo(-2),
              reason: '${component.runtimeType} hangs off the top',
            );
            expect(
              bounds.bottom,
              lessThanOrEqualTo(kSlideHeight + 2),
              reason: '${component.runtimeType} hangs off the bottom',
            );
          }
        },
      );

      testWithGame<DeathBySlidesGame>(
        'keeps content clear of the toolbar and status bar',
        DeathBySlidesGame.new,
        (game) async {
          final page = await settle(game, route);

          for (final component in contentOf(page)) {
            final bounds = absoluteRect(component);
            expect(
              bounds.bottom,
              lessThanOrEqualTo(kContentBottom),
              reason: '${component.runtimeType} overlaps the status bar',
            );
            expect(
              bounds.top,
              greaterThanOrEqualTo(kContentTop - 2),
              reason: '${component.runtimeType} overlaps the toolbar',
            );
          }
        },
      );
    });
  }

  // Text is left out above because its width is meaningless under the test
  // font. Its height is not, so rows of the light table can still be checked
  // for captions running into the slide numbers of the row below.
  testWithGame<DeathBySlidesGame>(
    'light table keeps each row of captions clear of the next row',
    DeathBySlidesGame.new,
    (game) async {
      final table = await settle(game, Routes.lightTable);

      final thumbnails = table.children.whereType<SlideThumbnail>().toList();
      for (final upper in thumbnails) {
        for (final lower in thumbnails) {
          if (lower.position.x != upper.position.x ||
              lower.position.y <= upper.position.y) {
            continue;
          }
          final upperBottom = _texts(upper).map((r) => r.bottom).reduce(max);
          final lowerTop = _texts(lower).map((r) => r.top).reduce(min);
          expect(
            lowerTop,
            greaterThanOrEqualTo(upperBottom),
            reason:
                'slide ${lower.level.number} runs into the captions of '
                'slide ${upper.level.number}',
          );
        }
      }
    },
  );
}

Iterable<Rect> _texts(SlideThumbnail thumbnail) =>
    thumbnail.children.whereType<TextComponent>().map(absoluteRect);

/// Pushes [route], runs the entrance animations to completion and returns the
/// page, with the game sized to exactly one slide so absolute positions are
/// slide coordinates.
Future<SlidePage> settle(DeathBySlidesGame game, String route) async {
  game.onGameResize(Vector2(kSlideWidth, kSlideHeight));
  await game.ready();
  if (game.router.currentRoute.name != route) {
    game.router.pushNamed(route);
    await game.ready();
  }
  // Three seconds is comfortably past the last staggered fly-in.
  advance(game, 3);
  await game.ready();

  // The route below stays mounted, so take the page off the active route
  // rather than searching the whole tree.
  final page = game.router.currentRoute.children
      .whereType<SlidePage>()
      .single;
  expect(page.scale.x, 1);
  expect(page.position, Vector2.zero());
  return page;
}

/// Every positioned descendant that carries content and has a layout-defined
/// size, i.e. excluding:
///  * the slide chrome, which deliberately spans the full width;
///  * the drifting autoshapes, which are rotated, so an axis-aligned box means
///    little;
///  * [TextComponent]s, whose width comes from the font -- and `flutter test`
///    substitutes a test font that is one em per character, so their measured
///    widths here bear no relation to the real ones.
Iterable<PositionComponent> contentOf(SlidePage page) {
  return page.descendants().whereType<PositionComponent>().where((component) {
    if (component is Toolbar ||
        component is StatusBar ||
        component is FloatingAutoshape ||
        component is TextComponent) {
      return false;
    }
    if (component.ancestors().any((a) => a is Toolbar || a is StatusBar)) {
      return false;
    }
    return !component.size.isZero();
  });
}

Rect absoluteRect(PositionComponent component) {
  final topLeft = component.absoluteTopLeftPosition;
  final scale = component.absoluteScale;
  return Rect.fromLTWH(
    topLeft.x,
    topLeft.y,
    component.size.x * scale.x,
    component.size.y * scale.y,
  );
}
