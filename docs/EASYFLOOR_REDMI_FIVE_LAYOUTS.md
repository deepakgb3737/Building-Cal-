# Redmi five-layout drawing-board review

Date: 2026-10-17. Device: connected Redmi, adb ID d7a8dc04.
These tests ran on the physical phone using Flutter-injected touch gestures.
They are not manual finger tests or feedback from a human participant.

## Results

| Layout | Drawing | Wall/corner editing | Exact length | Undo/redo | Pinch | Screenshot review |
| --- | --- | --- | --- | --- | --- | --- |
| L-shape, 6 segments | Pass | Pass | Pass | Pass | Pass | Readable, associated dimensions |
| U-shape, 8 segments | Pass | Pass | Pass | Pass | Pass | Inner/outer labels remain separate |
| T-shape, 8 segments | Pass | Pass | Pass | Pass | Pass | Stem and arm dimensions remain distinct |
| Angled irregular outline, 6 segments | Pass | Pass | Pass | Pass | Pass | Diagonal labels have clear wall leaders |
| Four-room crossing partitions, 12 segments / 9 corners | Pass | Pass | Pass | Pass | Pass | Separate segment labels; busier but no visible overlap |

Command: `flutter test integration_test/easy_floor_complex_layouts_test.dart -d d7a8dc04`.
All **5 device tests passed**, 93 seconds excluding build/install. The test creates
geometry through the board, not by injecting a prebuilt plan. Each layout checks
live wall selection/dimensions, committed wall movement, corner movement, exact
entry, exact geometry restoration through history, and geometry-preserving
two-finger navigation. Network deserialization validates the geometry after edits.
Editing targets one representative wall and its corner in each layout, not every
wall or every possible drag direction. The angled-layout workflow edits its
first horizontal wall; diagonal dimensions are visually inspected, not a claim
that this run exercises every diagonal drag.

## Observations and changes

No reproducible new production defect was found in these five workflows.
Consequently, no geometry rules, snap thresholds, toolbar controls or display
defaults were changed. Added the repeatable integration test and retained these
actual device screenshots:

- [L-shape](easyfloor-device-review/L.png)
- [U-shape](easyfloor-device-review/U.png)
- [T-shape](easyfloor-device-review/T.png)
- [Angled outline](easyfloor-device-review/angled.png)
- [Shared-wall junctions](easyfloor-device-review/junctions.png)

Dense shared-room labels are visually busier than an isolated room but identify
individual split segments; hiding equal values indiscriminately would make those
segments ambiguous. No change was justified by these images alone.

## Additional verification and limits

The full automated suite passed **752 tests**. Analysis reports no errors or
warnings, with 62 pre-existing informational notices. The new test is formatted.

A proposed repeat with sampled/jittered strokes and an extra delete/undo check
did **not** execute: both repeat installation attempts returned
`INSTALL_FAILED_USER_RESTRICTED: Install canceled by user`. Those unverified
additions were removed; the retained integration script matches the passed
baseline apart from const/import lint cleanup. Existing unit/widget tests still
cover rough strokes and deletion, but that is not a substitute for this blocked
device repeat. Android install approval was not bypassed.

This is a debug-build, portrait, one-device review. It does not prove release-mode
frame pacing, manual finger comfort, all screen sizes, real keyboard variants or
performance on dense building-scale plans. The known dense-label performance
risk remains. A real first-time human usability session is still needed before
claiming human validation.

## Approved repeat

The user subsequently approved installation. The sampled/jittered-stroke and
delete/Undo repeat completed with five passing Redmi workflows after fixing a
residual-point simplification defect. The current script now accepts the
straightening preview explicitly, rather than choosing Keep Original and then
incorrectly expecting straightened geometry. See
[Rough-stroke repair and final evidence](EASYFLOOR_ROUGH_STROKE_REPAIR.md).
The final full suite passed 756 tests; the one-device/manual-testing limitations
above still apply.
