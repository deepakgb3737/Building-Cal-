# EasyFloor drawing-board audit

Date: 2026-10-15. Scope: active connected-wall engine and drawing workspace only.
No doors, areas, saving, export, backend, or other product features were added.

## Verification Boundary

Passing below means the stated automated geometry, widget-gesture, or canvas
checks passed, not that every possible drawing or physical device was verified.
Tests inspect actual geometry and rendered label behavior, not only widget presence.
Native manual testing was attempted but blocked because the Mac was locked.
Flutter detected macOS and Chrome only; no Android device was connected, and
wireless iOS discovery failed with code -27. Physical mobile testing: **not tested**.

## Requested Scenarios

| # | Scenario | Result | Evidence and limits |
| --- | --- | --- | --- |
| 1 | Rough square and rectangle | Passing, automated | Real noisy gesture paths; conservative cleanup suggestion; accepted square has equal sides and rectangle retains proportions. Cleanup remains optional. |
| 2 | L, U, T, irregular, angled, multi-room | Passing, automated | Natural continuous-outline tests, diagonal preservation, shared-room partition and geometry editing tests. Not arbitrary handwritten shapes on hardware. |
| 3 | Continuous multi-corner strokes | Passing, automated | Connected outlines and long continuous-stroke regression; simplification retains intended tested corners. |
| 4 | Wall/corner starts, guides and snapping | Passing, automated | Hold-to-start partition on existing wall, endpoint and midpoint connections, competing targets, guide appearance/removal and optional assistance. |
| 5 | Shared room wall movement | Passing, automated | Actual partition drag preserves its length, shared junction degree and independent geometry; straight-run movement requires explicit opt-in. |
| 6 | Repeated corner edits | Passing, automated | Ten alternating real pointer drags return to original coordinates; attached graph remains connected. Engine stress checks cover repeated group edits. |
| 7 | Exact dimensions and units | Passing, automated | Dialog entry tested for every DrawingUnit: mm, cm, m, ft, inches, ft/in; switches do not rescale geometry; conflicting locked dimensions reject atomically. |
| 8 | Angle indicators | Passing, automated | Included 90/180/45-degree values, contextual visibility and distinction from absolute direction. Native visual legibility not verified. |
| 9 | Draw/select/move/zoom conflicts | Passing, automated | Near-corner targeting, stable nearby-wall target, label drag, pinch navigation, interrupted stroke and preset resize. |
| 10 | Undo/redo/cancel | Passing within tested operations | Multi-update drag is one history edit; drawing/corner/group/preset/pan cancellation, split/join, exact edits, calibration, deletion, undo during drag and tool switching covered. Every possible interleaving and platform interruption is not tested. Camera navigation is not a geometry-history operation. |
| 11 | Dense/narrow/short/zoomed layouts | Passing, automated | Short endpoint self-snap, competing wall targets, 320px live-label paint, label collision checks, small rooms, 100m narrow corridor, dense intersections, fit-zoom edits and group movement. |
| 12 | Increasing complexity and responsiveness | Passing, debug samples only | Preview/finalization/canvas-command timing at 60, 220 and 840 walls. Sustained release-mode GPU frame rate and long physical-device sessions: not tested. |

## Defects Reproduced and Fixed

1. A short wall's dragged endpoint snapped to its own attached neighbour,
   collapsing the wall. Corner-edit snapping now excludes collapse-producing
   neighbouring corner/projection targets; normal drawing connections remain enabled.
2. Undo during a drag could be overwritten by later events from the same pointer.
   Restore now cancels the active transaction before applying history.
3. Switching tools during a drag could commit an abandoned preview. Tool changes
   and fit/exact-edit actions now resolve active edits first; destructive/group
   controls are disabled during the relevant active interaction.
4. OS gesture cancellation discarded a preset draft. Per-gesture draft checkpoints
   now restore its dimensions, placement, and pending polygon state.
5. Cancelling camera movement left the camera displaced. Cancellation restores its
   pre-gesture origin and scale without adding a geometry history entry.
6. A second finger could commit a partial stroke or leave a preset resized. Pointer
   arrival now switches to navigation before scale-recognizer completion, rolling
   back the edit and restoring pending drafts.
7. Draft measurement labels remained visible during navigation. They now follow
   the same navigation suppression as contextual dimensions and angles.
8. A verbose live direction label could fail placement on a 320px canvas. Removing
   the redundant word keeps the reproduced length/angle label visible.
9. Dense-layout finalization scanned unnecessary intersection pairs, corners and
   duplicate edges. Bounding-box rejection, shared-endpoint rejection, corner
   buckets and edge keys reduce work while retaining junction/constraint remapping.

Each behavioral fix has a regression in `board_audit_regressions_test.dart` or
`board_audit_scenarios_test.dart`. Both sets of gesture defects were observed as
failing tests before the corresponding fix. The timing regression is measured
without a flaky time-limit assertion.

## Timing Samples

Median of five debug samples, local Flutter test process; microseconds.
Finalization includes transaction validation and junction connection. These are
not rendered device frame times. Comparing separate runs introduces noise.

| Walls | Corners | Finalization before | Finalization after |
| --- | --- | --- | --- |
| 60 | 36 | 1894 | 459 |
| 220 | 121 | 6128 | 587 |
| 840 | 441 | 53057 | 3469 |

The 840-wall after-run preview median was 765us and canvas command-recording
median 2126us. No GPU rasterization or physical touch latency was measured.
See `test/features/easy_floor/board_audit_benchmark_test.dart` to reproduce.

## Project Checks

- Full `flutter test --no-pub`: 173 tests passing.
- `flutter analyze`: no errors or warnings; 69 informational style diagnostics
  remain, including legacy code. Analysis is not lint-clean.
- macOS debug hot reload completed. This is not manual interaction verification.

## Remaining Limits

- Constraint validation rejects incompatible movement; it is not an automatic
  architectural constraint solver that repositions unrelated walls.
- Dense geometry or viewport edges can still leave no collision-free label
  position. Lower-priority labels may be omitted rather than cover geometry.
- Extremely short walls at low zoom have overlapping finger targets. Zooming in
  is still required to distinguish their midpoint from their endpoints.
- Shape recognition is intentionally conservative; it must not coerce an
  irregular outline into a rectangle. Unrecognized paths remain editable walls.
- Junction pair enumeration remains quadratic, although expensive work is now
  filtered. Thousands of walls need profiling before claiming responsiveness.
- Geometry history retains 50 edits. Raw gesture paths are bounded/simplified.
- Android/iOS touch feel, stylus hardware, release-mode frame pacing, every OS
  interruption and sustained long-session behavior remain unverified.

The reported defects are fixed in the tested scope. Universal drawing-board
perfection and the full physical-device definition of done are not established.
