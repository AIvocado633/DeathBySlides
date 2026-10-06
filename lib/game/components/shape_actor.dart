import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../art/actor_art.dart';
import '../art/shape_art.dart';
import '../slide/motion.dart';
import '../theme/palette.dart';

export '../art/actor_art.dart' show ActorState, Facing;

/// A character in the game -- the player, or one of the slide-editor features
/// they are trying to defeat.
///
/// An actor is always in a state: [walking] or not decides between walk and
/// idle, and [hit] and [die] play once on top of that. Artwork for each state
/// comes from PNG frames (see [ShapeArt] and `docs/art-pipeline.md`), with
/// fallbacks all the way down to idle. Without any frames the actor draws a
/// procedural stand-in built from the same autoshapes the real art will be
/// made of, which shows every state too.
class ShapeActor extends PositionComponent {
  ShapeActor({
    required this.actor,
    this.tint = Palette.brand,
    this.stepTime = 0.14,
    this.bobbing = true,
    super.position,
    super.size,
    super.anchor,
  });

  /// Which actor's frames to use: `hero`, `shrink_to_fit`, ...
  final String actor;

  /// Colour used by the placeholder stand-in.
  final Color tint;

  final double stepTime;

  /// Whether the actor bobs gently while idle. Decoration, so it stops with
  /// [Motion.reduced] -- and starts again if that is turned back off.
  final bool bobbing;

  /// How long a hit lasts when the actor has no hit frames of its own.
  static const double defaultHitDuration = 0.3;

  PositionComponent? _view;
  SpriteAnimationComponent? _sprite;
  _PlaceholderCreature? _placeholder;
  MoveEffect? _bob;
  ActorFrames _frames = ActorFrames.none('');

  /// True once real artwork was found and mounted.
  bool get hasArtwork => _sprite != null;

  /// What the actor is showing now.
  ActorState get state => _oneShot ?? _base;

  /// Walk or idle: what a one-shot returns to.
  ActorState _base = ActorState.idle;
  ActorState? _oneShot;
  double _oneShotLeft = 0;

  /// Whether the actor is on the move. Takes effect straight away, or once a
  /// hit has played out.
  bool get walking => _base == ActorState.walk;
  set walking(bool walking) {
    final base = walking ? ActorState.walk : ActorState.idle;
    if (base == _base) {
      return;
    }
    _base = base;
    _show();
  }

  /// Whether the actor is pleased with itself. Like [walking], a state to
  /// rest in, which a hit plays over.
  bool get cheering => _base == ActorState.cheer;
  set cheering(bool cheering) {
    final base = cheering ? ActorState.cheer : ActorState.idle;
    if (base == _base) {
      return;
    }
    _base = base;
    _show();
  }

  /// Which way the actor faces. Westward facings are drawn mirrored.
  Facing get facing => _facing;
  Facing _facing = Facing.south;
  set facing(Facing facing) {
    if (facing == _facing) {
      return;
    }
    _facing = facing;
    scale.x = facing.isWestward ? -1 : 1;
    _show();
  }

  /// Plays the hit once, then goes back to walking or idling. A second hit
  /// starts it again; nothing interrupts dying.
  void hit() {
    if (_oneShot == ActorState.die) {
      return;
    }
    _oneShot = ActorState.hit;
    _oneShotLeft = _durationOf(ActorState.hit);
    _show(restart: true);
  }

  /// Plays dying once and holds the last frame for good.
  void die() {
    if (_oneShot == ActorState.die) {
      return;
    }
    _oneShot = ActorState.die;
    _show(restart: true);
  }

  /// How long [state] runs: its own frames if it has them, otherwise
  /// [defaultHitDuration].
  double _durationOf(ActorState state) {
    final found = _frames.animationFor(state, _facing, stepTime: stepTime);
    if (found == null || found.loops) {
      return defaultHitDuration;
    }
    return found.animation.frames.length * stepTime;
  }

  @override
  Future<void> onLoad() async {
    _frames = await ShapeArt.loadActor(actor);
    final PositionComponent view;
    if (_frames.hasArtwork) {
      view = _sprite = SpriteAnimationComponent(
        size: size.clone(),
        position: size / 2,
        anchor: Anchor.center,
      );
    } else {
      view = _placeholder = _PlaceholderCreature(size: size.clone(), tint: tint)
        ..position = size / 2
        ..anchor = Anchor.center;
    }
    _view = view;
    _shownPrefix = null;
    _show();
    await add(view);
  }

  String? _shownPrefix;

  /// Puts the right frames up for [state] and [facing]. Leaves a looping
  /// animation running when nothing about it changed, and starts a one-shot
  /// from its first frame when [restart] is asked for.
  void _show({bool restart = false}) {
    _placeholder?.state = state;
    final sprite = _sprite;
    if (sprite == null) {
      return;
    }
    final found = _frames.animationFor(state, _facing, stepTime: stepTime);
    if (found == null) {
      return;
    }
    final key = '${found.prefix}${found.loops}';
    if (key == _shownPrefix && !(restart && !found.loops)) {
      return;
    }
    _shownPrefix = key;
    sprite.animation = found.animation;
    sprite.animationTicker?.reset();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_oneShot == ActorState.hit) {
      _oneShotLeft -= dt;
      if (_oneShotLeft <= 0) {
        _oneShot = null;
        _show();
      }
    }
    _placeholder?.elapsed += dt;
    _updateBob();
  }

  /// The idle bob runs while standing, cheering or flinching, not while
  /// walking or dying, and never with [Motion.reduced].
  void _updateBob() {
    final view = _view;
    if (view == null) {
      return;
    }
    final wanted =
        bobbing &&
        !Motion.reduced &&
        (state == ActorState.idle ||
            state == ActorState.cheer ||
            state == ActorState.hit);
    final bob = _bob;
    if (!wanted && bob != null) {
      bob.removeFromParent();
      _bob = null;
      view.position = size / 2;
    } else if (wanted && bob == null) {
      view.add(
        _bob = MoveEffect.by(
          Vector2(0, -10),
          EffectController(
            duration: 1.3,
            alternate: true,
            infinite: true,
            curve: Curves.easeInOut,
          ),
        ),
      );
    }
  }
}

Color _darken(Color colour, [double amount = 0.16]) {
  final hsl = HSLColor.fromColor(colour);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// A monster assembled from plain autoshapes: an oval body, two circle
/// eyes and a bullet point for an antenna.
///
/// It acts out every state, so they can be seen before any art exists:
/// a waddle to walk, a squash and screwed-up eyes when hit, crossed-out
/// eyes when it dies, and a grin with eyes smiling shut when it cheers.
class _PlaceholderCreature extends PositionComponent {
  _PlaceholderCreature({required Vector2 size, required this.tint})
    : super(size: size);

  final Color tint;

  ActorState state = ActorState.idle;

  /// Seconds since the creature appeared, which paces the waddle.
  double elapsed = 0;

  /// How far the waddle tips, and how often, in steps a second.
  static const double _waddleAngle = 0.12;
  static const double _waddleRate = 3;

  late final Paint _bodyPaint = Paint()..color = tint;
  late final Paint _bodyHighlight = Paint()..color = const Color(0x33FFFFFF);
  late final Color _shade = _darken(tint);
  late final Paint _outlinePaint = Paint()
    ..color = _shade
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  final Paint _eyeWhitePaint = Paint()..color = Palette.slide;
  final Paint _pupilPaint = Paint()..color = Palette.ink;
  final Paint _shadowPaint = Paint()..color = const Color(0x1A000000);
  late final Paint _mouthPaint = Paint()
    ..color = _shade
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round;
  final Paint _crossPaint = Paint()
    ..color = Palette.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round;

  /// How far the body leans this frame: side to side while walking.
  double get lean => state == ActorState.walk
      ? math.sin(elapsed * math.pi * 2 * _waddleRate) * _waddleAngle
      : 0;

  @override
  void render(Canvas canvas) {
    final unit = math.min(width, height) / 100;
    final centre = Offset(width / 2, height / 2 + 6 * unit);

    // Ground shadow, which stays put while the body above it moves.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centre.dx, height - 6 * unit),
        width: 56 * unit,
        height: 12 * unit,
      ),
      _shadowPaint,
    );

    canvas.save();
    // Waddle about the feet; squash towards them when hit.
    final feet = Offset(centre.dx, centre.dy + 36 * unit);
    canvas
      ..translate(feet.dx, feet.dy)
      ..rotate(lean);
    if (state == ActorState.hit) {
      canvas.scale(1.14, 0.84);
    }
    canvas.translate(-feet.dx, -feet.dy);

    // Antenna: a line topped with a bullet point.
    canvas.drawLine(
      Offset(centre.dx, centre.dy - 34 * unit),
      Offset(centre.dx, centre.dy - 50 * unit),
      _outlinePaint,
    );
    canvas.drawCircle(
      Offset(centre.dx, centre.dy - 54 * unit),
      6 * unit,
      _bodyPaint,
    );

    // Body.
    final body = Rect.fromCenter(
      center: centre,
      width: 70 * unit,
      height: 72 * unit,
    );
    final bodyRRect = RRect.fromRectAndRadius(body, Radius.circular(26 * unit));
    canvas.drawRRect(bodyRRect, _bodyPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(body.left, body.top, body.width, body.height * 0.42),
        Radius.circular(26 * unit),
      ),
      _bodyHighlight,
    );
    canvas.drawRRect(bodyRRect, _outlinePaint);

    // Eyes.
    for (final dx in [-16.0, 16.0]) {
      final eye = Offset(centre.dx + dx * unit, centre.dy - 12 * unit);
      canvas.drawCircle(eye, 11 * unit, _eyeWhitePaint);
      canvas.drawCircle(eye, 11 * unit, _outlinePaint);
      switch (state) {
        case ActorState.die:
          // Crossed out.
          final r = 6 * unit;
          canvas
            ..drawLine(eye.translate(-r, -r), eye.translate(r, r), _crossPaint)
            ..drawLine(eye.translate(-r, r), eye.translate(r, -r), _crossPaint);
        case ActorState.hit:
          // Screwed shut.
          canvas.drawLine(
            eye.translate(-6 * unit, 0),
            eye.translate(6 * unit, 0),
            _crossPaint,
          );
        case ActorState.cheer:
          // Smiling shut: an upturned arc.
          canvas.drawArc(
            Rect.fromCenter(center: eye.translate(0, 3 * unit), width: 12 * unit, height: 10 * unit),
            math.pi,
            math.pi,
            false,
            _crossPaint,
          );
        case ActorState.idle || ActorState.walk:
          canvas.drawCircle(
            Offset(eye.dx + 2 * unit, eye.dy + 1 * unit),
            5 * unit,
            _pupilPaint,
          );
      }
    }

    // A flat, unimpressed mouth; a small open one when it hurts; a grin,
    // for once, when it cheers.
    if (state == ActorState.cheer) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(centre.dx, centre.dy + 10 * unit),
          width: 30 * unit,
          height: 18 * unit,
        ),
        0,
        math.pi,
        false,
        _mouthPaint,
      );
    } else if (state == ActorState.hit || state == ActorState.die) {
      canvas.drawCircle(
        Offset(centre.dx, centre.dy + 17 * unit),
        5 * unit,
        _mouthPaint,
      );
    } else {
      canvas.drawLine(
        Offset(centre.dx - 14 * unit, centre.dy + 16 * unit),
        Offset(centre.dx + 14 * unit, centre.dy + 16 * unit),
        _mouthPaint,
      );
    }
    canvas.restore();
  }
}
