# Wall Movement: Two-Sided Touch Targets

## Root Cause And Fix

When a wall and corner target overlapped, `WallNetwork.hitTest` only preferred
the wall in its middle half and within half the intended wall hit radius.
Touches near a wall end or on the outer half of its invisible hit band could
become corner reshapes instead of parallel wall movement.

The shared hit test now considers the full wall body and the complete two-sided
16-logical-pixel band (32 pixels total). Endpoint cores stay reserved for corner
dragging. A core is at most six logical pixels and at most 20% of the wall's
projected length, so two endpoint cores cannot consume a short wall entirely.
All distances are converted to millimetres using the current camera scale.
Visible wall thickness and permanent geometry are unchanged.

Tap, automatic drag and endpoint-resize initiation continue to use the same hit
test. Wall movement now uses the full finger displacement in both the gesture
handler and geometry engine, rather than projecting onto the wall normal.
Horizontal, vertical and diagonal walls translate in every direction without
changing their own lengths or angles. A tangential component can reshape the
adjoining walls; it is no longer silently discarded to maintain a rectangle.
Shared endpoint IDs update attached geometry; unrelated corners are unchanged.
Automatic editing moves a connected straight run together. Existing locks,
intersection checks and minimum wall lengths still reject invalid moves.

No new tool, mode or toolbar was added. Exact endpoint touches still select
corners; one coordinate cannot simultaneously target both a corner and its wall.

## Translation Connections

Moving run endpoints snap to external wall endpoints or wall-interior projections
within 10 logical pixels, converted to world units by camera scale. One correction
translates the whole run; endpoints never snap independently and stretch it.
The moving run and its attached walls are excluded from snap targets. Near-end
projections that would create sub-10-mm segments are not offered. Feedback uses
the existing connection marker and guides. Connections become shared vertices on
release, as one undoable operation. Coincident endpoint merging preserves existing
wall IDs rather than unnecessarily splitting and replacing those walls.

Existing connections remain shared when moved away: attached walls update from
their fixed far endpoints. There is no implicit detach or geometry duplication.
Fixed dimensions, overlaps and crossings still reject invalid edits with feedback.
Optional grid assistance remains available, but angular assistance does not constrain
the direction of a wall translation.
If a proposed magnetic snap creates an overlap or violates a constraint, a valid
unsnapped position is retained instead. Invalid raw moves still report a conflict;
snapping cannot freeze an otherwise valid near-parallel placement.

## Automated Coverage

- Before the fix, all seven new side-selection/drag matrix tests failed.
- Three scale matrices cover 0.02, 0.1 and 1.0 pixels/mm, four orientations,
  short and long valid walls, both sides, centerline and near-end positions.
- Every rectangle wall is dragged from three positions along its length,
  three lateral offsets, and both perpendicular directions.
- Checks cover active highlighting, live dimensions, preserved length, unchanged
  opposite/unrelated corners, rectangular connectivity and exact cancellation.
- Existing shared-wall, partition, corner, snapping, pinch, Undo/Redo and geometry
  integrity tests remain in the full suite.
- `free_wall_movement_test.dart` covers 15-degree translation increments, four
  orientations, short/long walls, three camera scales, endpoint/T connections,
  shared-corner movement away from a join, stable IDs, Undo/Redo and cancellation.
  Widget tests cover body dragging in eight directions and after simulated 0.5x
  and 2x pinch zoom, plus live connection feedback and committed junctions.

## Physical Device Status

A Redmi Note 8 running Android 11 was detected. The integration test APK built
and installed successfully, but the first test could not finish: the display was
asleep, and waking it showed the proximity/pocket-mode overlay. These device
scenarios are **not verified**, and mobile acceptance remains outstanding.

The SDK-provided `integration_test` development dependency and
`integration_test/easy_floor_wall_sides_test.dart` provide repeatable on-device
rectangle, diagonal and partition/shared-wall checks, including movement from
both sides, along the wall, exact cancellation, commit and Undo.

Unlock the phone, uncover its proximity sensor, keep it awake, then run:

```sh
flutter test integration_test/easy_floor_wall_sides_test.dart -d d7a8dc04
```

This executes automated gestures on a physical device. Manual finger precision,
feel and compatibility with other phones are separate checks; no universal
mobile reliability claim is made.

Earlier two-sided-target checks: 381 tests passed; analysis had no errors/warnings and retained
65 informational notices. Chrome hot reload and the normal Android debug build
succeeded. The blocked device test was stopped rather than reported as passing.
Restoring the normal debug app was attempted without requesting data removal,
but Android rejected installation with INSTALL_FAILED_USER_RESTRICTED
(install cancelled by user). Normal-app restoration is therefore also pending
user approval of the USB installation prompt. Android
build tooling emitted existing AGP/Kotlin support-deprecation warnings; build
configuration upgrades were outside this wall-movement fix.
