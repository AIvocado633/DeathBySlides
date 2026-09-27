import 'dart:math' as math;

/// Hit points for a combatant.
///
/// In this fight health is not a bar, it is a size: Shrink-to-Fit shrinks
/// whatever does not fit, so both sides of the fight literally get smaller as
/// they lose. [scale] is the mapping from remaining points to how big the owner
/// is drawn.
class Health {
  Health({required this.max, this.minScale = 0.4})
    : assert(max > 0, 'A combatant needs at least one hit point'),
      assert(minScale > 0 && minScale <= 1, 'minScale must be in (0, 1]'),
      _current = max;

  final int max;

  /// How small the owner is drawn once it is out of hit points. Kept above
  /// zero so a dying combatant is still visible while its death plays out.
  final double minScale;

  int get current => _current;
  int _current;

  double get fraction => _current / max;

  bool get isDead => _current <= 0;

  /// Size multiplier for the current health, from 1 down to [minScale].
  double get scale => minScale + (1 - minScale) * fraction;

  /// Removes [amount] points and returns how many were actually taken, which
  /// is zero once the owner is already dead.
  int damage([int amount = 1]) {
    final taken = math.min(amount, _current);
    _current -= taken;
    return taken;
  }

  void restore() => _current = max;
}
