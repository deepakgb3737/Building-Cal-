# EasyFloor Final Drawing-Board Audit

## Additional Integrity Pass

Reviewed shared-wall movement, fixed and flexible dimensions, endpoint snapping,
parallel guides, corner targeting, anchored resizing, intersections, preview
rollback, history, zoom-scaled hit areas, selection rendering and safe deletion.
These features already exist; none were duplicated and the toolbar is unchanged.

A new failing regression demonstrated that `WallNetwork.fromJson` accepted a
wall's fixed-length metadata even when it contradicted its actual length or
had no measured-span lock. The common transaction validator now rejects both
states with an actionable conflict message. It builds a set of measured wall
IDs once per validation instead of scanning every span for each fixed wall.
It does not guess a replacement length, unlock a wall or change valid geometry.

Added combined regression coverage: lock a room's outer span, insert a shared
partition, move it, reject a crossing edit atomically, round-trip connected
geometry, undo/redo the whole move, delete the partition and join the outer
segments while retaining the locked span. The scenario passed before the repair;
it protects existing behavior against stricter validation.

The full suite passes 328 tests. Analysis has no errors/warnings and retains the
67 informational lints. Chrome debug compilation and hot reload were checked.
Android was disconnected; wireless iOS was detected but not deployed to. No new
physical-mobile gesture, sustained frame-rate or stylus claim follows from this
pass. The older audit sections below retain their original measurements and
platform evidence.

## Connected-Editing Follow-up

The floating toolbar is unchanged. A fresh baseline passed 322 tests. The new
short-wall gesture regression reproduced a real failure: touching the middle of
a 24-screen-pixel wall selected an endpoint because its 22-pixel corner hit area
covered the wall midpoint. A parallel wall drag consequently stretched the wall.

`WallNetwork.hitTest` now resolves this overlap in world coordinates. In the
middle half of a wall, a touch within the narrow wall band prefers that wall
when it lies outside the endpoint's inner grab area. Endpoint and actual shared
junction touches keep corner priority. Smart tap, drag initiation and length-mode
endpoint detection share this rule. Explicit corner tools and multi-selection
retain their previous behavior. Geometry, constraints, snapping, ruler dots,
units, shape cleanup and toolbar layout were not rewritten.

New automated checks cover horizontal/vertical/diagonal targets at three zoom
levels, near-endpoint priority, empty space, unchanged geometry during hit tests,
shared cross-junction movement and JSON topology, and actual short-wall drag with
Undo/Redo. A suspected unchanged-length calibration history issue was also
tested: the existing constraint signature already includes calibration, so no
calibration/history fix was needed.

Current full-suite result: 326 passing tests. Analysis has no errors/warnings;
67 existing informational diagnostics remain. Chrome debug hot reload verifies
compilation, not mobile touch feel. The latest device discovery found macOS and
Chrome only; Android was disconnected and wireless iOS discovery failed. The
physical-phone interaction scenarios remain unverified in this follow-up.

Debug medians (five samples, microseconds; not device FPS):

| Walls | Corner-edit preview | Junction finalization | Canvas recording |
| --- | --- | --- | --- |
| 60 | 390 | 578 | 1484 |
| 220 | 643 | 672 | 3105 |
| 840 | 1154 | 3199 | 3432 |

The older audit below is retained as historical evidence. Extremely tiny walls
whose entire screen extent falls inside an endpoint's inner grab area still
require zooming for unambiguous selection. The validator remains a conflict
checker, not an automatic building-wide constraint solver.

## Scope And Findings

Inspected the existing connected wall model, stroke refinement, shape presets,
precision assistance, history, gestures, dimension layout and ruler rendering.
Kept the existing engine rather than rebuilding it. No unrelated screens or
product features changed. The baseline full suite passed 304 tests.

Existing capabilities include shared-corner topology, split crossing and
T-junction walls, free and assisted angles, fixed dimensions and relationship
constraints, exact unit input, direct wall/corner editing, shape previews,
contextual dimensions, protected gesture cancellation and navigation.

Two rendering defects were reproduced with seven failing raster tests:

1. Live preview dots were painted before the preview wall stroke, which covered
   the dots. They are now painted after the stroke and before endpoint handles.
2. Multi-wall previews received dots only on the last segment. Every preview
   segment now receives its own world-spaced ruler markings, including every
   square, rectangle, triangle, L-, U- and T-preset wall.

No additional geometry defect was reproduced in this audit. That is not a proof
that arbitrary layouts or all hardware combinations are defect-free.

## Workflow Matrix

Passing means automated unit/widget/raster verification unless stated otherwise.
Existing suites listed here were rerun, not merely assumed to work.

| Scenario | Result | Evidence in test/features/easy_floor/ |
| --- | --- | --- |
| Rough square/rectangle and optional refinement | Pass | sketch_refinement_test, sketch_refinement_interaction_test, board_audit_scenarios_test |
| Triangle, L/U/T, irregular and open outlines | Pass | shapes_units_angles_test, complete_board_audit_test, sketch_refinement_test |
| Shared rooms, midpoint partitions, cross-junctions | Pass | wall_network_test, smart_geometry_test, reliability_test |
| Direct wall/corner editing and unrelated geometry | Pass | board_audit_scenarios_test, advanced_geometry_test, complete_board_audit_test |
| Fixed A/B and symmetric resizing, conflicts | Pass | wall_resize_test, wall_resize_interaction_test |
| Exact mm/cm/m/ft/in/ft-in dimensions | Pass | shape_interaction_test, shapes_units_angles_test |
| Contextual labels and meaningful angles | Pass | context_display_test, line_alignment_test, cardinal_assistance_test |
| Endpoint/alignment snapping at different zooms | Pass | drawing_guides_test, line_alignment_test, advanced_interaction_test |
| Refine/keep/preview/accept, undo/redo | Pass | sketch_refinement_interaction_test, sketch_history_test |
| Cancel, delete, select-all, clear and recovery | Pass | reliability_interaction_test, complete_board_audit_test, advanced_interaction_test |
| Pan/pinch, fit control, empty double-tap | Pass | navigation_resize_test, drawing_camera_test |
| Competing targets and interrupted gestures | Pass | advanced_interaction_test, board_audit_regressions_test, navigation_resize_test |
| Repeated connected-layout edits | Pass | complete_board_audit_test (60 mixed cycles) |
| Short/overlapping walls, nearly closed strokes | Pass | wall_network_test, reliability_test, natural_drawing_test, sketch_refinement_test |
| Always-on 2 ft dots, larger 4 ft multiples | Pass | wall_markers_test |
| Dot positions and adaptive radii across zoom | Pass | wall_markers_test (horizontal/vertical/diagonal) |
| Visible live/preset dots above preview strokes | Pass | drawing_render_audit_test (seven raster checks) |
| Android debug build and launch | Pass after retry | Redmi Note 8, Android 11/API 30 |
| Android portrait/landscape visual inspection | Partial | Captured actual drawing workspace and pending-sketch preview; no visible overflow in those captured states |
| Physical-device complete gesture workflow | Not verified | ADB input injection denied INJECT_EVENTS; no security settings changed |
| iOS physical interaction | Not tested | Wireless device detected, not deployed to |
| Release-mode sustained frame pacing/stylus input | Not tested | Debug timings do not establish these properties |

## Checks And Performance

- Full suite after repair: 311 passing tests, including seven new raster checks.
- flutter analyze: no errors/warnings; 67 informational style diagnostics remain.
- Android assembleDebug succeeded. Initial deployment stopped at USB installation
  approval and disconnected; after reconnection, the debug app launched.
- Chrome debug build and hot reload succeeded. The raster preview was also
  inspected locally; Flutter test fonts are placeholders, not native typography.
- Saved documents were not cleared or overwritten during the audit.

Debug benchmark medians of five samples from the full-suite run, microseconds:

| Walls | Corner-edit preview | Junction finalization | Canvas command recording |
| --- | --- | --- | --- |
| 60 | 310 | 499 | 1791 |
| 220 | 671 | 709 | 2935 |
| 840 | 1225 | 2939 | 3612 |

These are local test-process CPU measurements, not Android GPU timings or FPS.
The debug Android launch logged skipped frames during startup; this was not a
controlled interactive performance test. Gradle/AGP/Kotlin future-support
warnings also remain; upgrading the Android build stack was outside this scope.

## Remaining Limits

The validator rejects incompatible constraints rather than solving an entire
building automatically. Shared-corner changes necessarily affect attached
walls. Tiny walls at low zoom can have overlapping touch targets; zooming is
needed for precision. Labels can be omitted when no uncluttered position exists.
Dots remain physically spaced but become subpixel at extreme zoom-out.

Geometry uses floating-point millimetres; a sketch needs a known real dimension
for meaningful scale. The app is not a sensor-based measuring instrument. History
retains 50 edits. Large intersection graphs still need sustained target-device
profiling. This audit establishes the tested scope, not universal perfection.
