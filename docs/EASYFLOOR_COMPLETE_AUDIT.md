# EasyFloor Complete Drawing Board Audit

Date: 2026-10-15. Scope: active drawing board only.

## Architecture Decision: Repair, Not Rebuild

Inspection covered `wall_network.dart`, `drawing_point.dart`, `drawing_history.dart`,
shape recognition/presets, precision assistance, guides, angles, the canvas painter,
gesture handlers, editing dialogs, controls, and existing regression tests.

The architecture is suitable for this scope:

- `WallNetwork` is the authoritative connected graph. Walls reference shared
  corner IDs, including split T/cross junctions. It stores millimetres, not pixels.
- Geometry-changing operations work on validated copies and commit atomically;
  incompatible dimensions, overlaps and invalid movement produce conflicts.
- Shape cleanup, precision assistance, angle calculations and guides are pure
  Dart helpers. Geometry logic contains no Flutter/canvas dependencies.
- Canvas rendering and camera transforms remain separate from geometry.
- History snapshots include graph topology, constraints and calibration state.
- Existing tests exercise real widget gestures and state transitions as well as
  isolated formulas. The baseline full suite passed 184 tests.

A rebuild would discard working topology and transaction handling without fixing
the actual defects more effectively. The exposed defects were recognition gaps
and editing-command/selection lifecycle issues, not a failed graph model.
No new dependency, backend, persistence, or unrelated app feature was introduced.

## Pre-Change Findings

| Requirement | Existing Status | Evidence / Gap |
| --- | --- | --- |
| Freehand and individual walls, open/closed/irregular layouts | Working in tested scope | Continuous L/U/T and irregular gesture tests; endpoint/midpoint snapping and stylus-event test. |
| Shape cleanup and presets | Partial | Square/rectangle/triangle/L recognition and all presets existed. Rough eight-corner U/T recognition returned null. |
| Smart wall/corner editing and navigation | Working with safety gaps | Existing direct-edit and pinch tests passed. Wall commands remained callable against an unfinished drag. |
| Connected shared-wall/junction editing | Working in tested scope | Shared-wall moves, corner edits, splits/joins, constraints and reconnection tests passed. |
| Group selection following reconnection | Defective | Joining a group wall to another endpoint split the selected wall and left its removed ID selected. Subsequent group commands could reference missing geometry. |
| Exact dimensions and units | Working in tested scope | All six units and calibration/rectangle/individual-wall editing tests passed. |
| Angles and temporary guides | Working in tested scope | Parallel/perpendicular, diagonal references, contextual angles, extension/centerline and competing-target tests existed. |
| Undo/redo and cancellation | Mostly working | Existing tests passed; unfinished shape/group commands and clear-confirmation timing needed stronger safeguards. |
| Dense-layout performance | Partially verified | Debug timing samples and engine stress tests exist; sustained release-mode device performance was not established. |
| Physical mobile usability | Not tested | No Android or usable iOS device available; native Mac inspection blocked by locked desktop. |

## Repairs

### Conservative U/T Recognition

Extended the existing local recognition helper, not the drawing model. Eight-corner
near-orthogonal outlines qualify only with the expected coordinate levels and two
re-entrant corners. Their cyclic separation distinguishes U and T layouts in
either winding. Existing correction limits, minimum lengths, topology validation,
preview acceptance/rejection and irregular-shape preservation remain in effect.

Tests cover rough outlines in both windings at 0, 37 and 90 degrees, open outlines,
angled irregularities, and actual touch-stroke cleanup followed by exact editing
and complete undo/redo. Recognition remains conservative, not arbitrary semantic
room recognition or a promise to recognize every handwriting style.

### Selection Integrity After Junction Changes

After finalizing a gesture, verify that selected wall/corner IDs still exist.
When reconnection has replaced selected segments, clear the selection and explain:
"Connections changed. Select the walls again to continue editing."

This deliberately avoids guessing which newly split walls the user intended to
delete or constrain. Geometry remains intact, Delete becomes unavailable without
a selection, and Undo/Redo restore the connected edit as a single operation.

### Safe Commands During Active Gestures

- Wall inspector commands are hidden while a geometry drag is in progress,
  matching the existing corner-inspector behavior. Contextual canvas measurements
  remain available during editing.
- Group completion and relationship removal cannot commit an unfinished drag.
- Preset placement, dimensions/rotation and polygon completion wait for gesture
  release. Cancel remains available.
- Opening Clear plan first cancels the unfinished gesture. Cancelling its
  confirmation cannot accidentally commit the pending stroke when the finger lifts.

## Required Workflow Results

All Passing entries below refer to automated tests, not physical-device testing.

| Scenario | Result | Verification |
| --- | --- | --- |
| Draw and correct a rough square | Passing | Noisy stroke, cleanup preview/accept, equal sides and right angles; existing square tests retained. |
| Draw irregular multi-room layouts | Passing | Continuous irregular/L/U/T paths, sequential shared partitions, separate irregular outlines and connected-grid stress. |
| Connect a partition at a wall midpoint | Passing | Actual hold-and-draw partition gesture; shared corner IDs and split segments checked. |
| Move a wall shared by rooms | Passing | Partition drag and straight-run movement; connected endpoints and unrelated geometry checked. |
| Exact dimensions in different units | Passing | mm/cm/m/ft/in/ft-in dialog tests, unit switching, calibration, locked conflicts, U/T exact-edit workflows. |
| Move a corner while preserving connections | Passing | Repeated real drags, cancellation and dense graph edits; attachment identities and unrelated geometry retained. |
| Draw diagonal walls and edit angles | Passing | Free/assisted angles, diagonal references, preset rotation, corner movement, direction versus included-angle tests. |
| Undo/redo complex operations | Passing | Split/join, group reconnection, duplication/deletion, exact edits, calibration, two-step shape workflows and graph snapshots. |
| Cancel a stroke without modifying geometry | Passing | Direct cancellation, navigation transitions, clear-confirmation cancellation and abandoned previews. |
| Draw/edit at different zoom levels | Passing | Fit-zoom editing, group displacement, world-based angles and zoom-converted touch/guide tolerances. |
| Select and delete multiple walls | Passing | Existing group/delete confirmation, selected-corner attachments, select-all/clear and history tests; stale-selection guard added. |
| Repeated complex-plan edits | Passing | 60 mixed cycles on a connected grid plus independent irregular geometry; positive lengths, unique edges, shared touching nodes and snapshots checked. |
| Finger/stylus behavior on Android/iOS hardware | Not tested | Only synthetic touch/stylus events were exercised. |
| Native desktop visual inspection | Not tested | Computer-use inspection returned a locked-Mac error. |
| Sustained release-mode mobile performance | Not tested | Debug CPU/command-recording timing is not GPU frame rate or real touch latency. |

## Checks

- Baseline `flutter test --no-pub`: 184 passing.
- Full suite after repairs: 196 passing, including 12 new tests in
  `test/features/easy_floor/complete_board_audit_test.dart`.
- `flutter analyze`: no errors/warnings; 69 informational style diagnostics remain.
- macOS debug hot reload completed; it does not establish native visual quality.
- `flutter devices --device-timeout 2`: macOS and Chrome only. Wireless iOS
  discovery failed with code -27; no Android device detected.

The first focused run reproduced missing U/T recognition, an active-drag wall
command surface, and stale group selection before implementation repairs.
All newly added workflow checks pass after repairs. Some test fixtures also
needed correction: expected models must be copied before mutable edits, toolbar
buttons must be scrolled into view, and tooltip lookup is not an IconButton lookup.

Debug benchmark from the full-suite run (median of five samples, microseconds):

| Walls | Preview | Finalization | Canvas command recording |
| --- | --- | --- | --- |
| 60 | 379 | 548 | 1365 |
| 220 | 673 | 646 | 1816 |
| 840 | 1274 | 3520 | 2492 |

These are local debug measurements under test-run load, not pass/fail performance
thresholds. No FPS guarantee follows from them.

## Remaining Limits

- The strict geometry validator explains incompatible constraints; it is not an
  automatic solver that repositions other rooms to satisfy every requested size.
- Moving a shared corner necessarily changes attached walls. Unrelated geometry
  is preserved, but room-shape preservation needs explicit constraints.
- Real intersections become shared junctions; disabling endpoint assistance does
  not create disconnected layers at actual crossings.
- Walls have centerlines but no thickness, so guides cannot claim physical
  wall-face alignment. Angles are smaller included angles, not detected interior
  or reflex room angles.
- At very low zoom, short walls have overlapping finger targets; zooming or an
  explicit tool is still necessary. Dense/edge-of-viewport labels can be omitted
  when no safe non-overlapping position exists.
- History retains 50 edits. Raw strokes are bounded/simplified. Intersection pair
  enumeration remains quadratic despite broad-phase filtering; thousands of walls
  require further profiling before performance claims.
- Dimensions use floating-point millimetres. Sketch scale is nominal until a known
  dimension is established; the app is not a sensor-based measuring instrument.
- The large gesture/UI state class remains a maintainability risk. A wholesale
  rewrite was not justified by the observed defects; further changes need the
  existing interaction regressions and explicit per-gesture rollback checks.

The tested repairs are complete. The full physical-usability definition of done
remains unverified until Android/iOS and unlocked-desktop testing are performed.
