/// Whether motion that is only decoration should stay still.
///
/// One switch for the whole game, set by the game from Design Ideas (or, until
/// the player chooses, from the device's own accessibility setting). Fly In
/// entrances, the drifting autoshapes, the actors' idle bob and every hit
/// flash and shake read it. Motion that is the game -- walking, shots, a boss
/// moving -- never does.
abstract final class Motion {
  static bool reduced = false;
}
