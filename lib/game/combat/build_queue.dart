import 'dart:math' as math;

/// What kind of effect a build step is, and so the colour of its star.
enum EffectKind { entrance, emphasis, exit }

/// The effects the Build Order can play: each one is an attack named after it.
enum BuildEffect {
  /// Shots sweep in from one edge.
  flyIn('Fly In', EffectKind.entrance, duration: 1.2),

  /// A rotating spiral.
  spin('Spin', EffectKind.emphasis, duration: 1.6),

  /// An expanding ring with a gap in it.
  pulse('Pulse', EffectKind.emphasis, duration: 0.9),

  /// A wall crossing the arena, with one way through.
  wipe('Wipe', EffectKind.exit, duration: 1.8),

  /// A few shots that bounce around the walls.
  bounce('Bounce', EffectKind.entrance, duration: 1.1),

  /// A wobbling stream aimed at you.
  wobble('Wobble', EffectKind.emphasis, duration: 1.2);

  const BuildEffect(this.label, this.kind, {required this.duration});

  final String label;
  final EffectKind kind;

  /// How long the effect runs once started, in seconds.
  final double duration;
}

/// When a step plays.
enum Trigger {
  /// When the player clicks -- and every bullet point fired is a click.
  onClick('On Click'),

  /// Together with the step before it.
  withLast('With Last'),

  /// Once everything before it has finished.
  afterLast('After Last');

  const Trigger(this.label);

  final String label;
}

/// One entry in the Build Order: an effect, and what sets it off.
class BuildStep {
  const BuildStep(this.id, this.effect, this.trigger);

  /// Stable across reorders and deletions, unlike the number on screen.
  final int id;
  final BuildEffect effect;
  final Trigger trigger;

  @override
  String toString() => '#$id ${effect.label} (${trigger.label})';
}

/// The queue of steps and the rules for when each plays: plain data and a
/// pure scheduler, so trigger behaviour is testable without a running game.
///
/// The queue plays from the top and starts again when it runs out, until it
/// has been emptied:
///
/// * [Trigger.withLast] starts the moment the step before it starts.
/// * [Trigger.afterLast] waits until nothing is running, and [gap] more.
/// * [Trigger.onClick] waits for a click, and one click starts one step.
class BuildQueue {
  BuildQueue(Iterable<BuildStep> steps, {this.gap = 0.5, double startDelay = 1})
    : _steps = [...steps],
      _idle = gap - startDelay;

  /// Seconds of quiet an After Last step waits for.
  final double gap;

  final List<BuildStep> _steps;

  /// The steps, in the order they will play.
  List<BuildStep> get steps => List.unmodifiable(_steps);

  bool get isEmpty => _steps.isEmpty;
  int get length => _steps.length;

  /// Where in [steps] the next step to start is.
  int get cursor => _cursor;
  int _cursor = 0;

  /// The step that plays next, or null once the queue is empty.
  BuildStep? get next => _steps.isEmpty ? null : _steps[_cursor];

  /// Steps playing now, with the seconds each has left.
  final Map<BuildStep, double> _running = {};
  Iterable<BuildStep> get running => _running.keys;

  /// Seconds since the last step finished and nothing was running.
  double _idle;

  /// Moves the queue on by [dt] seconds, with [clicked] if the player fired
  /// since the last update, and returns the steps that started.
  List<BuildStep> update(double dt, {bool clicked = false}) {
    for (final step in [..._running.keys]) {
      final left = _running[step]! - dt;
      if (left <= 0) {
        _running.remove(step);
      } else {
        _running[step] = left;
      }
    }
    if (_running.isEmpty) {
      _idle += dt;
    } else {
      _idle = 0;
    }

    final started = <BuildStep>[];
    var click = clicked;
    while (_steps.isNotEmpty) {
      final step = _steps[_cursor];
      final ready = switch (step.trigger) {
        Trigger.withLast => true,
        Trigger.afterLast => _running.isEmpty && _idle >= gap,
        Trigger.onClick => click,
      };
      // Never more than one lap in one go, however the triggers line up.
      if (!ready || started.length >= _steps.length) {
        break;
      }
      if (step.trigger == Trigger.onClick) {
        click = false;
      }
      _running[step] = step.effect.duration;
      _idle = 0;
      started.add(step);
      _cursor = (_cursor + 1) % _steps.length;
    }
    return started;
  }

  /// Deletes the step with [id]. An effect already playing plays out.
  void remove(int id) {
    final index = _steps.indexWhere((step) => step.id == id);
    if (index < 0) {
      return;
    }
    _steps.removeAt(index);
    if (_steps.isEmpty) {
      _cursor = 0;
      return;
    }
    if (index < _cursor) {
      _cursor--;
    }
    _cursor %= _steps.length;
  }

  /// Shuffles the steps and starts reading from the top again: the queue
  /// the player has been reading changes under them.
  void reorder(math.Random random) {
    _steps.shuffle(random);
    _cursor = 0;
  }

  /// The seventeen steps the Build Order opens with.
  static List<BuildStep> opening() {
    const plan = [
      (BuildEffect.flyIn, Trigger.onClick),
      (BuildEffect.spin, Trigger.withLast),
      (BuildEffect.bounce, Trigger.afterLast),
      (BuildEffect.pulse, Trigger.onClick),
      (BuildEffect.wipe, Trigger.afterLast),
      (BuildEffect.wobble, Trigger.withLast),
      (BuildEffect.flyIn, Trigger.afterLast),
      (BuildEffect.spin, Trigger.onClick),
      (BuildEffect.pulse, Trigger.withLast),
      (BuildEffect.bounce, Trigger.afterLast),
      (BuildEffect.wobble, Trigger.onClick),
      (BuildEffect.wipe, Trigger.afterLast),
      (BuildEffect.flyIn, Trigger.withLast),
      (BuildEffect.pulse, Trigger.afterLast),
      (BuildEffect.spin, Trigger.onClick),
      (BuildEffect.bounce, Trigger.withLast),
      (BuildEffect.wobble, Trigger.afterLast),
    ];
    return [
      for (final (i, (effect, trigger)) in plan.indexed)
        BuildStep(i + 1, effect, trigger),
    ];
  }
}
