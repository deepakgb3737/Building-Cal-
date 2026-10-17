# EasyFloor Natural Drawing Audit

Date: 2026-10-16. Scope: the existing 2D board and geometry engine only.

## Reference Principles

[SketchUp's drawing and inference guidance](https://help.sketchup.com/en/sketchup/introducing-drawing-basics-and-concepts)
describes live measurements, precise numeric entry, and temporary endpoint,
intersection, parallel and perpendicular inference.
[SketchUp's grouping guidance](https://help.sketchup.com/en/sketchup/grouping-geometry)
explains separate geometry groups and lock/unlock. EasyFloor adapts these as
existing direct-touch operations, not additional CAD modes or a new toolbar.

## Defects And Repairs

- Whole-network translation rechecked every internal wall pair although one
  uniform translation cannot change their relative intersections. The shared
  `moveCorners` path now skips only those unchanged pairs. External geometry,
  non-rigid edits, short segments and constraints remain validated atomically.
- A room move with no independent external geometry no longer computes faces
  again just to search for external containment.
- Selecting a text note could leave an entire room highlighted behind its
  editor. Text selection now clears the transient room selection, not geometry.
- Automatically selected shapes had no direct lock control. Their contextual
  inspector now exposes Lock lengths / Unlock lengths and the selected wall
  count. One batch action is one undoable atomic operation and does not move
  coordinates. No toolbar or permanent panel was added.

## Acceptance Matrix

All passing entries below are automated, not physical-phone verification.

| Scenario | Result | Evidence in `test/features/easy_floor/` |
| --- | --- | --- |
| Draw a room naturally | Pass | `drawing_screen_test.dart`, `natural_drawing_test.dart` |
| Resize a side with opposite side fixed | Pass | `simple_room_resize_test.dart`, `wall_sides_test.dart` |
| Enter an exact dimension in supported units | Pass | `dimension_submission_test.dart`, `shapes_units_angles_test.dart` |
| Preserve irregular/freehand intent | Pass | `sketch_refinement_test.dart`, `free_drawing_intent_test.dart` |
| Connect endpoints and wall-midpoint junctions | Pass | `endpoint_connection_test.dart` |
| Move entire shapes without distortion | Pass | `whole_shape_move_test.dart` |
| Direct wall/corner touch priority | Pass | `automatic_touch_test.dart`, `whole_shape_move_test.dart` |
| Nearby independent shapes stay separate | Pass | `whole_shape_move_test.dart` |
| Labels target correct segments after editing | Pass | `every_wall_labels_test.dart`, `measurement_layout_test.dart` |
| Undo/Redo and cancelled edits | Pass | `gesture_recovery_test.dart`, `whole_shape_move_test.dart` |
| Two-finger pan/zoom and gesture switching | Pass | `pinch_reliability_test.dart`, `navigation_switching_test.dart` |
| Wall/shape locking and narrow-screen controls | Pass | `accessible_lock_test.dart`, `natural_board_audit_test.dart` |
| Note selection does not retain wall-group feedback | Pass | `natural_board_audit_test.dart` |
| Real mobile finger/stylus interaction | Not tested | Physical-device testing remains deferred |

## Follow-Up Workflow Repairs

- Room alignment now evaluates X and Y independently. An already-aligned edge
  no longer suppresses a useful alignment on the other axis. Unsafe two-axis
  placement tries safe single-axis alternatives before retaining the requested gap.
- Whole-room guides reference the relevant moving and stationary corners, with
  no self-alignment or distant-room guides. Geometry remains the source of truth.
- Pending sketch and preset actions remain accessible in the existing contextual
  area while the toolbar is collapsed. No automatic reopening or extra mode is used.
- `room_alignment_regression_test.dart` covers the alignment defect at three
  scales, safe collision fallback and guide association. `natural_complete_journey_test.dart`
  covers the complete draw/resize/exact-entry/partition/irregular-room/group-move/
  delete/undo/pinch/continue journey on 320 and 430 logical-pixel widths, plus
  collapsed review on 240-pixel portrait and 740-pixel landscape layouts at 1.6x text.
- These are automated widget/model checks. Physical finger/stylus testing,
  first-time-user usability and device performance remain unverified.

## Performance And Limits

A diagnostic desktop Dart VM probe on the same 840-wall grid measured room
translation at 115,067 microseconds before and 1,687 microseconds after repair.
These are single-run geometry timings, not a rendering/frame-rate guarantee or
phone measurement. `board_audit_benchmark_test.dart` now records five-sample
median group translation timings alongside selection and 400 x 800 canvas
painting, and asserts unchanged wall IDs and uniform corner offsets.

Length locks are not absolute-position pins. Whole-shape rigid translation can
preserve a locked length; connected edits that would violate it are rejected.
Shared-wall rooms move as one connected network. Text notes remain independent.
Freehand recognition is conservative and major corrections still require review.
Crowded labels may require zooming. Real-device latency, long-session behavior,
and extremely dense interactive plans remain unverified.
