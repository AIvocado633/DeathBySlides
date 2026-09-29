# Drawing the monsters

Every character in this game — the player and the features they are fighting —
is built out of plain autoshapes in a slide editor and exported as PNG. That is
a hard constraint: if a sprite could not have been built out of rectangles,
ovals and arrows, it does not belong in the game.

Any slide or vector editor will do (LibreOffice Impress, Keynote, Inkscape, …).
The steps below happen to use PowerPoint, because that is what the first
sprites were drawn in; the game itself is not tied to any one editor.

This document is the contract between the deck and the code.

## Where things live

| What | Where |
| --- | --- |
| Source decks | `art/*.pptx` (not created yet — add them as you draw) |
| Exported frames | `assets/images/` |
| Loader | [`lib/game/art/shape_art.dart`](../lib/game/art/shape_art.dart) |
| Component that draws an actor | [`lib/game/components/shape_actor.dart`](../lib/game/components/shape_actor.dart) |

## Naming

Frames are a zero-padded sequence sharing a prefix:

```
assets/images/hero_idle_000.png
assets/images/hero_idle_001.png
assets/images/hero_idle_002.png
```

Each sequence loads `000`, `001`, … and stops at the first missing number. A
single still is just a one-frame sequence.

### States

The prefix is `<actor>_<state>_`, and every state is optional except `idle`:

| State | Plays | Used when |
| --- | --- | --- |
| `idle` | loops | standing still — the fallback for everything else |
| `walk` | loops | moving |
| `hit` | once, then back to `idle` or `walk` | taking a hit |
| `die` | once, holding the last frame | beaten; the exit effects run on top |

Which actors use which:

| Actor | Prefix | States it plays |
| --- | --- | --- |
| The presenter (menu and fights) | `hero` | `idle`, `walk`, `hit`, `die` |
| Shrink-to-Fit | `shrink_to_fit` | `idle`, `hit`, `die` |
| Diagram Wizard — one shape, repeated for every node | `diagram_wizard` | `idle`, `hit`, `die` |
| Master Template — the face on the master thumbnail | `master_template` | `idle`, `hit`, `die` |
| Snap to Grid — the face in the grid dialog | `snap_to_grid` | `idle`, `hit`, `die` |

### Directions

Art can also be drawn per direction, as `<actor>_<state>_<dir>_`, for the five
directions `s`, `se`, `e`, `ne` and `n`. The other three are the mirror image
of their eastern twin (`sw` of `se`, `w` of `e`, `nw` of `ne`), so they are
never drawn. Only the presenter turns, so only `hero` gains anything from
directional art; bosses always face the player (`s`).

```
assets/images/hero_walk_e_000.png   walking east, and mirrored for west
assets/images/hero_walk_n_000.png   walking north
```

### What is shown when art is missing

For a state and a facing, the first of these that exists is shown:

1. `<actor>_<state>_<dir>_` — that state, drawn for that direction
2. `<actor>_<state>_` — that state, drawn once for every direction
3. `<actor>_idle_<dir>_` — idle, drawn for that direction
4. `<actor>_idle_` — idle

An actor with only idle frames therefore looks exactly as it did before
states existed. When `hit` falls back to idle, idle keeps looping and the hit
simply lasts 0.3 seconds. Without any idle frames the actor draws its
procedural stand-in throughout (see below). Every actor's frames load once and
are shared, so switching state never touches the disk.

## Drawing rules

- **One pose per slide.** Slide 1 is frame `000`, slide 2 is frame `001`, and
  so on. Keep each animation in its own deck.
- **Keep the character the same size and in the same place on every slide**, or
  it will jitter when the frames play. Use *View ▸ Guides* and leave the
  character's feet on the same guide in every pose.
- **Draw at roughly 512×512.** Sprites are scaled down in game, so exporting
  larger than you need costs nothing but a few KB and keeps them crisp on
  high-DPI phones.
- **Group each pose** (select everything on the slide, <kbd>Ctrl</kbd>+<kbd>G</kbd>).
  Export needs one shape per slide, and grouping also stops you nudging a leg
  out of place by accident.

## Exporting with a transparent background

This is the step that goes wrong. *File ▸ Export ▸ PNG* exports whole slides,
background included, which gives you a white box around every monster.

Instead, export the shape:

1. Select the grouped pose on the slide.
2. Right-click ▸ **Save as Picture…**
3. Choose **PNG**, name it `hero_idle_000.png`, save into `assets/images/`.

PowerPoint writes the shape's own bounds with a transparent background.

### Doing it in bulk

For anything longer than a few frames, a macro beats clicking. Open the deck,
press <kbd>Alt</kbd>+<kbd>F11</kbd>, insert a module and adapt:

```vb
' Assumes exactly one (grouped) shape per slide.
Sub ExportFrames()
    Const Prefix As String = "hero_idle_"
    Const Folder As String = "C:\path\to\DeathBySlides\assets\images\"
    Dim sld As Slide
    For Each sld In ActivePresentation.Slides
        sld.Shapes(1).Export _
            Folder & Prefix & Format(sld.SlideIndex - 1, "000") & ".png", _
            ppShapeFormatPNG, 512, 512
    Next sld
End Sub
```

Treat this as a starting point rather than a tested script — check the first
few files it writes before trusting a whole run, and note that the deck must be
saved as `.pptm` for the macro to persist.

## Using the art in game

Drop the PNGs into `assets/images/` and restart the app (a hot *reload* will not
pick up new assets; hot *restart* or a full run will). Nothing else is needed:
`assets/images/` is registered wholesale in `pubspec.yaml`, and `ShapeActor`
looks its frames up by prefix.

```dart
ShapeActor(
  actor: 'hero',
  size: Vector2.all(230),
)
```

The actor picks its frames itself from what it is doing: set `walking` and
`facing`, and call `hit()` and `die()`.

### Until the art exists

`ShapeActor` falls back to a procedural stand-in — a monster made of the same
autoshapes the real art will be made of — so pages stay laid out and animated
while the deck is still being drawn. It acts out the states too: a waddle to
walk, a squash with screwed-shut eyes when hit, and crossed-out eyes when it
dies. You will see one line per missing actor in
the console:

```
ShapeArt: no frames named "hero_idle_000.png" in assets/images/ - falling back to placeholder art.
```

That message disappears on its own once the frames are in place.

## Adding a new monster

1. Draw it in a new deck, one pose per slide, one deck per state.
2. Export as `<actor>_idle_000.png`, … into `assets/images/`, and the same for
   any of `walk`, `hit` and `die` it has.
3. Add a `ShapeActor(actor: '<actor>')` where you want it, and call `hit()` and
   `die()` on it where the boss takes a hit and is beaten.
4. If it is a boss, set its slide's `buildBoss` in `kLevels`, in
   [`lib/game/levels.dart`](../lib/game/levels.dart), to its constructor. The
   arena needs no changes.
