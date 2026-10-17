# BuildCalc

## Project Credit

**This project was built using AI-assisted development under the direction of
the BuildCalc team. The calculation formulas, business rules, requirements and
domain decisions were developed and supplied by our team, not invented by AI.**

Third-party libraries, Flutter-generated platform code and the bundled EasyFloor
reference package retain their own authorship and licenses. AI assistance does
not replace engineering review or independent verification of calculations.
See [Authorship and third-party notices](NOTICE.md).

Licensed under the [MIT License](LICENSE). Third-party components retain their
respective licenses.

A Flutter app with grid ceiling planning, unit conversion, area conversion, calculator, compass, and drawer calculation tools.

Home also includes Paint, Flooring Tiles, Concrete Volume and Plaster estimates,
with separate calculation engines, your supplied icons, editable product rates,
and copyable results. See [Material Calculators](docs/MATERIAL_CALCULATORS.md) for
formulas, references, input limits and estimate assumptions. These four tools use
the shared form in `lib/ui/material_estimate_screen.dart`; each has its own
`lib/features/<tool>/logic/` and `ui/` folder.

## Before Editing

EasyFloor opens a drawing-only workspace with connected walls, shared corners,
live dimensions, snapping, hand resizing, exact lengths, constraints, undo/redo
and pan/zoom. It also provides optional shape-cleanup suggestions,
whole-chain straightening with a cancelable preview (under selected-wall More
options), conservative contextual line alignment, editable
shape presets, contextual angle indicators, feet-and-inches units, and undoable
whole-plan selection/deletion, partial multi-selection/group editing, persistent
wall-relationship locks, and known-dimension plan calibration. The geometry engine in `lib/features/easy_floor/logic/` stores mm
independently of widgets and screen pixels. See [EasyFloor Drawing](docs/EASYFLOOR_DRAWING.md).
See [Whole-stroke refinement](docs/EASYFLOOR_WHOLE_STROKE_REFINEMENT.md) for
chain boundaries, preview behavior, validation and verification limits.
Preset dimensions use a live lettered diagram, editable L/U/T arm sizes and the
same geometry as placement. Keyboard-safe scrolling keeps focused labels and
inputs visible; compact views scroll the preview while actions stay accessible.
L presets support four mirrored orientations with consistent A/B/C/D mapping;
the preview reflects rotation and mirroring. Invalid inputs hide stale previews
and show L-arm conflicts beside the corresponding field.
See [Preset dimensions](docs/EASYFLOOR_PRESET_DIMENSIONS.md).
The imported package in `packages/easy_floor/` is retained as a reference; its
room-path editor is no longer the active screen.
See the [drawing-board audit](docs/EASYFLOOR_BOARD_AUDIT.md) for verified scenarios,
reliability fixes, timing samples, and device-testing limitations.
The [complete repair-or-rebuild audit](docs/EASYFLOOR_COMPLETE_AUDIT.md) records the
decision to retain the connected engine, U/T cleanup, interaction-safety repairs,
and the latest workflow checks.
The [final drawing-engine audit](docs/EASYFLOOR_FINAL_ENGINE_AUDIT.md) records the
current workflow matrix, preview-ruler repairs, performance samples and the
limits of Android device validation. The [professional 2D workflow audit](docs/EASYFLOOR_PROFESSIONAL_AUDIT.md)
records the continuous acceptance test, snap-ranking and label-target repairs,
desktop timing samples and current device-testing limitations. See also
[Wall movement verification](docs/EASYFLOOR_WALL_MOVEMENT.md) for full-length,
two-sided wall targeting and physical-device test status.
90° drawing assistance is enabled by default to help users reach
0/90/180/270 degrees and perpendicular/straight continuations of attached walls
(including diagonal walls), without forcing arbitrary diagonal strokes. The
preceding freehand segment also supplies a local angle reference. Basic wall connections
are always enabled, including in older documents with snapping previously off:
endpoints snap within 16 logical pixels converted to real drawing coordinates.
A connection indicator previews endpoint drags; release merges shared corners
or splits an existing wall at a junction. Undo reverses the connection.
Switch to Free Angle under Drawing assistance to disable this assistance;
angular tolerance remains configurable there. In Wall, drag from an unselected
open endpoint to draw the next connected wall without holding. Tap that endpoint
first to select it for corner dragging instead. Shared corners and wall interiors
retain hold-to-branch; Draw retains direct corner editing. Open outlines are not
automatically closed by sequential Wall strokes.
See [Smart right-angle drawing](docs/EASYFLOOR_SMART_RIGHT_ANGLES.md) for
interaction rules, regression coverage and device-testing limits.
The visible Show labels / Hide labels button controls all-wall measurements after
drawing. Active drawing/editing still provides contextual measurements; the same
visibility is controlled in that one place, not duplicated in Drawing assistance.
New plans show essential overview dimensions by default; explicit saved Show/Hide
preferences remain unchanged. Labels toggles overview measurements; isolated rectangles
show one label per dimension and squares show one `All sides` label. Junctions,
partitions, irregular shapes and locked walls retain necessary segment labels;
saved visibility preferences remain supported. Wall labels stay screen-sized during
pan/zoom and use full real-world wall lengths even when
only part of a wall is visible. Placement avoids walls, corners, notes and other
labels and contextual inspectors; every segment dimension has a subtle leader to its own wall. Labels
leave the wall's invisible drag zone clear so wall and measurement touches do not
compete. Crowded
labels can use available canvas space beyond the local search. Active edits temporarily hide
unrelated labels even with Show labels enabled. All affected walls get active
priority ahead of essential overview labels; secondary angle/offset information
is suppressed when zoomed out or crowded. A live drawing label can use clear
space farther away with a leader when local positions are blocked. Dragging a
measurement selects its wall without moving geometry; tapping still opens exact
entry. Display values trim padding zeros;
exact dimension input retains its precision.
The [Text tool](docs/EASYFLOOR_TEXT.md) adds independent multi-line room labels and
notes with formatting, dragging, text-group selection, duplication/deletion and
shared Undo/Redo. Text does not alter wall geometry. Named documents persist both
wall geometry and annotations, including dimensions, constraints, calibration,
units and view settings. The Documents menu provides Save, Save As, New, Open,
rename/delete and protected switching. See [EasyFloor Documents](docs/EASYFLOOR_DOCUMENTS.md)
for workflows, storage limits and verification. The two-row toolbar keeps primary
actions and named drawing tools visible. Shapes opens seven presets in one
labelled grid; More holds drawing help and assistance. Smart editing remains automatic.
There is no idle Select/Move button: touching walls, corners and room interiors
selects them automatically. Cancel replaces More during an active gesture without
changing row size. Draw (freehand) and Wall (one straight segment) remain directly
accessible without duplicate entries in Shapes.
Drawing-table tools now use a movable, collapsible floating palette, without
reserving a top panel or permanent help strip. See
[Floating Drawing Tools](docs/EASYFLOOR_FLOATING_TOOLS.md). Hide UI removes the
header, palette and inspectors; the small Show Tools button restores them with
their previous state. Active measurements and guides remain visible. A request
during a canvas gesture waits for that gesture to finish safely.
The small N/S/E/W "Plan axes" overlay stays at a fixed screen position in both
normal and distraction-free modes. North is up, South down, East right and West
left. This is a drawing reference, not geographic North or a sensor reading;
the overlay ignores touches and does not participate in wall geometry.
Wall and Draw are directly accessible on the drawing toolbar. Wall
turns a drag into one straight segment; Draw keeps the sketch/refinement
workflow. Choosing either enables automatic drawing and wall/corner editing,
including from Text, without choosing a wall/corner editing mode. Text and Pan
toggle off with a second tap. Redundant manual wall/corner modes and duplicate
menu entries have been removed. Empty-canvas
hints and Drawing help in More drawing tools explain the gestures without
adding another toolbar or interrupting a sketch.
Pan switches to camera-only dragging. Two fingers pan/zoom in other modes, and
dragging a closed room's empty interior now translates its entire connected wall
network. Wall/corner and dimension-label touches retain priority. Shared rooms
and attached partitions move together; independent rooms stay separate. Gentle
axis alignment checks both axes independently and falls back to a safe single-axis
placement or the requested gap if snapping would collide. Guides reference the
actual nearby moving corners, not just the first corner. Cancel and second-finger
navigation restore the pre-drag geometry; Undo/Redo treats the move as one edit.
To intentionally connect rooms, use the existing endpoint-editing gestures.
Selected shapes show their connected-wall count and direct Lock lengths /
Unlock lengths controls, plus Delete with confirmation of the connected-wall
scope. Deleting a shape preserves independent walls and notes; Undo restores it.
These batch actions are atomic, preserve coordinates when locking,
and use the same measured-length constraints as individual walls. Rigid moves
skip unchanged internal intersection checks while retaining external-collision
and constraint validation. See the [natural drawing audit](docs/EASYFLOOR_NATURAL_AUDIT.md).
Two fingers still navigate, and
double-tapping empty canvas or using Fit to Screen brings walls and full text
annotations into view. Selected text has a bottom-right resize handle; preset
shapes have a separate corner handle. See [Navigation And Resizing](docs/EASYFLOOR_NAVIGATION.md).
Room resizing needs no lock setup: drag a side or tap its dimension. Exact entry
focuses and selects the current length immediately and accepts the keyboard
Done/Enter action in every supported unit. The scrollable editor reveals the
focused field as keyboard/viewport sizes change and retains values through rotation, with the same
validation as Apply (both fields are validated for rectangle dimensions).
Exact room resizing keeps four-sided rectangles rectangular. Wall dragging
translates the selected wall in every direction while its length/angle stay
unchanged; adjoining walls update from their unmoved far endpoints. Tangential
motion may deliberately reshape the room rather than being discarded.
Selected walls expose Lock length / Unlock length directly beside
Enter length and Delete. Locked walls reject direct dragging and ordinary exact
length changes until unlocked; lock/unlock is undoable. These remain measured
length constraints, not absolute-position pins for every connected/group edit.
Locked wall strokes use the shared red drawing color, including when selected;
selection retains its thicker stroke. Measurement labels contain dimensions,
not redundant lock-status text. Unlock restores the existing normal/selected
wall color. Split segments use their measured-span lock state consistently.
Advanced fixed-A/B and centered resizing remain under More wall options. Always-on wall
dots mark every 2 ft, with larger dots every 4 ft and no marker numbers. See
[Wall Resizing And Scale Dots](docs/EASYFLOOR_WALL_RESIZING.md).
Freehand sketches now offer a single post-stroke review and a separate refinement
preview. With tools collapsed, pending sketch/preset actions appear temporarily
in the existing contextual area without reopening the toolbar; they disappear
after placement or cancellation. Dense collinear strokes commit without a redundant review. Refinement
is validated against a copy of the current wall network; unsafe intersection
shortcuts retain the conservative original. Near-returning open sketches can propose endpoint closure, explicitly
labelled in the existing preview. Keep Original and Cancel refinement retain the
conservative open sketch;
Undo restores the original sketch preview and Redo restores refined walls;
a second Undo removes the sketch. Temporary stroke data stays outside saved
wall geometry. See
[Sketch Refinement](docs/EASYFLOOR_SKETCH_REFINEMENT.md).

See the [five-iteration quality log](docs/EASYFLOOR_FIVE_ITERATIONS.md) for the
latest snap, focus/keyboard and toolbar-obstacle repairs, regression evidence,
real-font visual previews and remaining device-validation limits.
The [workspace five-pass review](docs/EASYFLOOR_WORKSPACE_FIVE_PASS_REVIEW.md)
records the direct locked-corner rotation repair, fitting around the movable
toolbar, current regression results and the successful Android wall-interaction
retry after the initial lock-screen blocker was resolved.
See [Smart measurement labels](docs/EASYFLOOR_SMART_MEASUREMENT_LABELS.md) for the
five-pass label review, priority rules, tests and dense-layout/device limitations.

Read [RULES.md](RULES.md). [AGENTS.md](AGENTS.md) directs coding agents to the same rules.

## Calculator

Physical keyboards support digits, decimal points, operators, parentheses and percent. Enter (including numpad Enter) calculates, Backspace/Delete removes the last character, and Escape clears. Command/Control/Alt shortcuts and input while a modal is open are not intercepted.

Long-press the Calculator result to open its Copy option; there is no permanent result-copy button. Copy takes the complete displayed result. The Calculator also supports copying and reusing history results, parentheses, square, square root, reciprocal, and last-answer reuse. Extra operations are in the app bar's menu.

Invalid expressions, division by zero, negative square roots, and out-of-range values are rejected. Percent remains a simple divide-by-100 operation: `200 * 10% = 20`, while `200 + 10% = 200.1` (not a contextual percentage increase).

History stores the latest 30 entries in the current screen session, not across app restarts. Arithmetic uses floating-point numbers; displayed results are rounded to eight decimal places or scientific notation for very small/large values. This is not an exact-decimal financial calculator.

## Run

Use a Flutter installation compatible with `pubspec.yaml` and the locked dependencies.
The current lockfile requires Dart 3.13 or newer and Flutter 3.38.4 or newer.

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

The repository contains Android, macOS, and web platform folders. Device-specific capabilities, including compass sensors, depend on platform and hardware support.

The macOS app requires macOS 12.0 or newer. The Podfile applies the same minimum to generated pod targets; change deployment targets in source configuration, not generated files inside `macos/Pods/`.

## Shared UI

Grid Ceiling uses an unboxed measurement form, a visible quantity summary, a 3D/2D view selector, and a zoomable 2D plan. Material quantities, placement measurements, the legend, and per-row cutting measurements are always expanded, with jump links to key sections. Only cutting illustrations and installation notes are collapsible. Editing measurements clears the previous layout until recalculated. Main runner stock is 3048 mm (10ft), preserving the supplied formula; labels, cutting guides, and drawing joint spacing use this length. The previously identified tile-purchase and small-room placement issues remain unresolved.

| File | Purpose |
| --- | --- |
| `lib/ui/app_colors.dart` | Interface and drawing colors |
| `lib/ui/app_typography.dart` | Font family and shared text styles |
| `lib/ui/app_styles.dart` | Radii and button variants |
| `lib/core/theme/app_theme.dart` | Material theme and default component styling |
| `lib/ui/app_widgets.dart` | Reusable converter and numeric form fields |

Screens use these definitions. Screen-specific layout, responsive sizing, drawing geometry, and some legacy shadows/opacity/elevation remain local. See `RULES.md` before adding styling.

## Engines And Services

- `lib/features/grid_ceiling/logic/`: ceiling placements, tiles, material optimization, and cutting helpers.
- `lib/features/drawer/logic/`: equal and custom drawer calculations.
- `lib/features/calculator/logic/`: arithmetic expression evaluation.
- `lib/features/unit_converter/logic/`: length conversion.
- `lib/features/area_converter/logic/`: area unit conversion.
- `lib/features/area_calculator/logic/`: area calculation.
- `lib/features/compass/logic/`: heading smoothing and direction helpers.
- `lib/core/input_validation.dart`: shared input validation.

These are local Dart engines/services, not a remote backend server. Keep formulas separate from rendering. Ceiling summaries and drawings must consume consistent calculated data.

## Feature Structure

```text
lib/
  main.dart                 # Entry point and MaterialApp
  core/                     # Shared validation
  ui/                       # Shared theme, typography, styles, widgets
  features/
    home/ui/
    grid_ceiling/ui/         # Input screen and 2D/3D layouts
    grid_ceiling/logic/
    drawer/ui/
    drawer/logic/
    calculator/ui/
    calculator/logic/
    unit_converter/ui/
    unit_converter/logic/
    area_converter/ui/
    area_converter/logic/
    area_calculator/ui/
    area_calculator/logic/
    compass/ui/
    compass/logic/
```

Feature-specific tests are in `test/features/`; shared UI tests are in `test/ui/`. App smoke tests and cross-feature calculation tests remain at the test root. The area calculator code is retained but is not currently linked from Home.

## Verify

```sh
dart format lib test
flutter analyze
flutter test
```

Tests cover calculations, validation, shared UI, and selected mobile-layout cases. Real-device checks are still required for platform input, rendering, and sensor behavior.

## Android Release APK

```sh
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

A successful build does not establish that production signing or store distribution is configured.

## Maintenance

Update this README and `RULES.md` when shared UI locations or architecture boundaries change. Do not document unsupported platforms or unverified accuracy guarantees.

## Construction Color Theme

The supplied `assets/Theme /` palette is integrated in `lib/core/theme/build_calc_colors.dart`; the active light Material theme lives in `lib/core/theme/app_theme.dart`. `lib/ui/app_theme.dart` exports it for existing callers. `AppColors` maps existing interface tokens to this palette, preserving distinct ceiling drawing/material colors. Update runtime tokens in core, not the reference asset files. Light mode is active; dark mode is not enabled because existing custom widgets use light-specific tokens.
