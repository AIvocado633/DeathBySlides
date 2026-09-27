import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../audio/game_audio.dart';
import '../input/menu_input.dart';
import '../death_by_slides_game.dart';
import '../save/save_data.dart';
import '../theme/palette.dart';
import 'focusable.dart';
import 'motion.dart';
import 'slide_metrics.dart';

/// Base class for every screen in the game.
///
/// A [SlidePage] is a fixed [kSlideWidth] x [kSlideHeight] canvas that scales
/// itself to fit the window and centres itself, leaving letterbox bars on
/// screens that are not 16:9. Subclasses lay out their children in slide units
/// and never have to deal with the real screen size.
abstract class SlidePage extends PositionComponent
    with HasGameReference<DeathBySlidesGame> {
  SlidePage() : super(size: slideSize);

  /// Colour of the slide surface. Override for e.g. the projector-black used
  /// while a slide show is running.
  Color get surfaceColor => Palette.slide;

  /// Whether to draw the drop shadow that separates the slide from the desk.
  bool get castsShadow => true;

  final Paint _surfacePaint = Paint();
  final Paint _shadowPaint = Paint()
    ..color = Palette.slideShadow
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

  /// The music this page plays while it is on top, or null for silence.
  Track? get music => Track.menu;

  /// The effects this page may play, loaded as it opens so the first one
  /// sounds without a delay.
  Iterable<Cue> get cues => const [Cue.whoosh];

  @override
  void onMount() {
    super.onMount();
    final audio = game.audio..preload(cues);
    // Pages fly in as they open; with Reduce Motion they simply appear, and
    // there is nothing to whoosh.
    if (!Motion.reduced) {
      audio.play(Cue.whoosh);
    }
  }

  /// Called when the app stops being in front -- backgrounded on a phone, or
  /// the window losing focus on a desktop. A running fight pauses here.
  void onAppBackgrounded() {}

  /// Called when the player's progress changes while this page exists, e.g.
  /// when a slide is won on a page pushed on top of it. Pages that show
  /// progress rebuild those parts here; they built them first in `onLoad`.
  void onProgressChanged() {}

  Progress? _progressShown;

  @override
  void update(double dt) {
    super.update(dt);
    // Progress is immutable and replaced whenever it changes, so identity
    // says whether this page is out of date.
    final progress = game.save.data.progress;
    if (_progressShown != null && !identical(progress, _progressShown)) {
      onProgressChanged();
    }
    _progressShown = progress;
  }

  /// Whether arrows move focus across the slide by position, as on a grid,
  /// rather than back and forth through the page in reading order.
  bool get spatialFocus => false;

  /// Everything focus can land on, in reading order: top to bottom, then left
  /// to right.
  List<Focusable> get focusables {
    final all = descendants().whereType<Focusable>().where((f) => f.canFocus);
    return all.toList()..sort((a, b) {
      final ca = a.absoluteCenter;
      final cb = b.absoluteCenter;
      return ca.y != cb.y ? ca.y.compareTo(cb.y) : ca.x.compareTo(cb.x);
    });
  }

  /// What has focus. It is only drawn once [focusVisible] -- or while the
  /// mouse is over it -- so a touch player never sees a selection they did
  /// not make.
  Focusable? get focused => _focused;
  Focusable? _focused;

  /// Whether the player is steering with keys or a controller, so focus is
  /// drawn wherever it is.
  bool get focusVisible => _focusVisible;
  bool _focusVisible = false;

  /// Gives [target] focus, without showing it unless it already shows.
  void focusOn(Focusable target) => _focused = target;

  /// Gives [target] focus and draws it: for when a page wants the player's
  /// attention on one choice, as the slide show's result dialog does.
  void showFocusOn(Focusable target) {
    _focused = target;
    _focusVisible = true;
  }

  /// Handles a menu action while this page is on top.
  void onMenuAction(MenuAction action) {
    switch (action) {
      case MenuAction.up ||
          MenuAction.down ||
          MenuAction.left ||
          MenuAction.right:
        _moveFocus(action);
      case MenuAction.activate:
        final target = _validFocus();
        if (target != null) {
          _focusVisible = true;
          target.activate();
        }
      case MenuAction.back:
        onBack();
      // Only a running slide show pauses, and only the title slide starts one.
      case MenuAction.pause ||
          MenuAction.startFromBeginning ||
          MenuAction.startFromCurrent:
        break;
    }
  }

  /// Esc, controller B and Android back: back to the page underneath.
  void onBack() => game.router.pop();

  /// Where focus starts: the first thing in reading order, unless a page
  /// knows better.
  Focusable? get initialFocus => focusables.firstOrNull;

  /// The focused component, or [initialFocus] if focus has nowhere valid to
  /// be -- nothing chosen yet, or the component was rebuilt.
  Focusable? _validFocus() {
    final current = _focused;
    if (current != null && focusables.contains(current)) {
      return current;
    }
    return _focused = initialFocus;
  }

  void _moveFocus(MenuAction direction) {
    final current = _validFocus();
    if (current == null) {
      return;
    }
    // The first press only shows where focus is, so it never skips a choice
    // the player has not seen.
    if (!_focusVisible) {
      _focusVisible = true;
      return;
    }
    final next = spatialFocus
        ? _nearestFrom(current, direction)
        : _neighbourInOrder(current, direction);
    if (next != null) {
      _focused = next;
    }
  }

  Focusable? _neighbourInOrder(Focusable current, MenuAction direction) {
    final order = focusables;
    final step = direction == MenuAction.up || direction == MenuAction.left
        ? -1
        : 1;
    final index = order.indexOf(current) + step;
    return index >= 0 && index < order.length ? order[index] : null;
  }

  /// The closest focusable that lies in [direction] from [current], weighing
  /// sideways distance double so a step stays in its row or column when it
  /// can.
  Focusable? _nearestFrom(Focusable current, MenuAction direction) {
    final unit = switch (direction) {
      MenuAction.up => Vector2(0, -1),
      MenuAction.down => Vector2(0, 1),
      MenuAction.left => Vector2(-1, 0),
      _ => Vector2(1, 0),
    };
    final from = current.absoluteCenter;
    Focusable? best;
    var bestScore = double.infinity;
    for (final candidate in focusables) {
      final offset = candidate.absoluteCenter - from;
      final along = offset.dot(unit);
      if (identical(candidate, current) || along <= 1) {
        continue;
      }
      final sideways = (offset - unit * along).length;
      final score = along + 2 * sideways;
      if (score < bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    final factor = math.min(size.x / kSlideWidth, size.y / kSlideHeight);
    scale = Vector2.all(factor);
    position = (size - slideSize * factor) / 2;
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    if (castsShadow) {
      canvas.drawRect(rect.deflate(6), _shadowPaint);
    }
    canvas.drawRect(rect, _surfacePaint..color = surfaceColor);
  }
}
