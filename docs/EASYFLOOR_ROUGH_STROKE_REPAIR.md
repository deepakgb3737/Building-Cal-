# Approved Redmi rough-stroke repeat and repair

Date: 2026-10-17. This follows the baseline five-layout device review.

## Defect investigation

The first sampled-stroke run chose Keep Original through the existing integration
helper. Expecting six straight walls after explicitly declining cleanup was a
test error: preserving the 48 sampled segments was intentional. The helper now
has an opt-in refinement action that chooses Yes, Straighten and then Accept
refinement. Other callers keep their previous Keep Original behavior.

The corrected device run then exposed a real simplification defect: the U-shape
produced nine segments instead of eight, and the angled outline produced seven
instead of six. These failures reproduced in widget tests at 393 x 851.
Global stroke simplification could retain a point that became nearly collinear
with its final neighbours. One U-shape residual was only 12 mm away from the
intended straight segment despite a 30 mm refinement tolerance.

## Engine repair

Only the proposed refined path receives a residual-point cleanup. Meaningful
turns, reversal points and endpoints are preserved. A linear scan of the original
sample spans checks the complete proposed cleanup against the existing adaptive
tolerance; if it exceeds that tolerance, the old reduced path is retained. This
prevents successive local removals from flattening intentional curves.

Original-sketch data, connected geometry validation, explicit preview/acceptance,
undo history and the existing drawing toolbar remain unchanged. No dependency
or new drawing option was added. The new cleanup and its tolerance check are
linear passes; the pre-existing simplification algorithm is unchanged.

## Regression coverage

- Widget regressions reproduce the sampled U and angled shapes through actual
  drawing, preview and acceptance, requiring exactly 8 and 6 wall segments.
- An intentional curved-outline test requires all samples to remain within the
  declared refinement tolerance.
- Existing original-sketch, preview cancellation, attached-anchor and history
  scenarios remain covered by the refinement suites.
- The five-layout device script now supplies eight samples per edge with
  alternating 1.2 logical-pixel sideways jitter, accepts the preview, then tests
  representative wall/corner editing, exact dimensions, deletion/Undo and pinch.

## Final verification

After the repair all five sampled-stroke Redmi workflows passed in 118 seconds
excluding build/install: L, U, T, angled outline and crossing partitions.
The expected segment counts were 6, 8, 8, 6 and 12; the junction layout retained
9 shared corners. Deletion removed one selected wall and Undo restored the exact
geometry. All 756 automated tests passed. Analysis: no errors/warnings, 62 existing
informational notices. Changed Dart files were formatted; hot reload passed.

Reviewed screenshots from the final repaired build:

- [L](easyfloor-device-review/rough-L.png)
- [U](easyfloor-device-review/rough-U.png)
- [T](easyfloor-device-review/rough-T.png)
- [Angled](easyfloor-device-review/rough-angled.png)
- [Junctions](easyfloor-device-review/rough-junctions.png)

These are Flutter-injected gestures on a physical Redmi, not manual finger
comfort feedback. They do not establish release-mode frame pacing, every wall
direction, every phone/keyboard or all possible sketches.
