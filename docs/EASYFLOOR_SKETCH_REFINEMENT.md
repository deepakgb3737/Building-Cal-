# EasyFloor Sketch Refinement

Updated 2026-10-15. This extends stroke handling and the existing shape preview;
it does not replace the connected wall engine or add document-format fields.

## Interaction

1. Draw a continuous outline without interruption. Temporary input stays outside
   permanent wall geometry.
2. After release, multi-segment outlines and densely sampled freehand strokes
   ask once: **Straighten and refine this sketch?**
3. **Keep Original** retains the conservative sketch polyline. **Yes, Straighten**
   shows the proposed clean geometry against its original translucent trace.
4. **Accept refinement** validates and commits the proposal. **Cancel refinement**
   keeps the original instead. **Discard sketch** leaves the pre-stroke plan intact.

Single-wall mode, two-point gestures, and densely sampled collinear input remain
immediate when cleanup yields the same two-endpoint wall. These commits remain
undoable. Users are not questioned after every short straight wall. Drawing several corners in one
continuous stroke creates one review, not a prompt for each segment. New/Open,
Save and unsaved-change protection still recognize a pending sketch.

## Geometry

`logic/sketch_refinement.dart` operates exclusively on millimetre coordinates.
It removes duplicate/sub-10-mm samples (the existing wall engine's minimum),
retains endpoints where they can form valid walls and uses iterative
Douglas-Peucker reduction. Refined tolerance adapts to sketch extent and is capped
by the caller's zoom-converted three-logical-pixel tolerance. Meaningful bends
remain; uncertain shapes are not coerced into presets.

The original candidate uses at most 1 mm simplification tolerance and retains
rough angles. It is a conservative vector approximation, not a pixel-perfect
ink recording. Intentional curves remain a chain of straight wall segments;
this update does not introduce curved-wall objects, pressure or stroke styling.
The original is kept temporarily through review and is not stored as duplicate
wall geometry when refinement is accepted.

Existing conservative shape recognition handles square/rectangle/L/U/T outlines
and triangles. Recognition is disabled for strokes attached to existing wall
anchors, preventing preset corrections from relocating established junctions.
The general reduction retains connected endpoints. After release, a near-returning
open stroke may offer closure in its refinement candidate, never in Keep Original.
The gap must be at most both 12 logical pixels (four times the supplied
three-pixel tolerance) and 2% of the sketch extent. A temporary wall graph must
validate it as one simple cycle without extra junctions, overlaps or collapsed
segments. This check runs after the stroke, not on every touch sample.

The existing review explicitly says **Preview will join the nearby endpoints.**
Yes, Straighten shows the proposal before Accept refinement commits it. Keep
Original or Cancel refinement preserves the original open endpoints. Disabling
recognition, or drawing attached to existing anchors, disables this new closure
proposal. Existing explicit endpoint snapping/very-near-start closure remains
visible while drawing; basic endpoint connections are always enabled.

Long-stroke sampling no longer blindly deletes every other point. Conservative
buffer simplification retains real corners. Very detailed genuine shapes can
still require many vertices; arbitrary high-frequency input has not been
performance-certified. No recognizer can infer every sketch perfectly, so the
original/preview/accept workflow remains necessary.

Proposed cleanup is checked against a copy of the current plan before it is
offered. Removing a shallow bend can shift intersections and create sub-10-mm
fragments. If that proposal is invalid, the conservative original is retained
rather than presenting an unusable refined layout.

Acceptance runs on a copy through `WallNetwork.addPolyline`, preserving existing
junction, overlap, minimum-segment and constraint validation. Invalid geometry
shows the existing conflict message without modifying the plan. Refinement
history retains a temporary sketch snapshot separately from canonical geometry.
Undo restores the original review preview; Redo restores the refined walls.
A second Undo removes that sketch entirely. Restored previews can be refined
again, kept or discarded, without inserting raw input into the wall graph or
leaking it into another document. Keep Original remains one geometry edit.
Documents continue to persist only canonical walls/annotations, not raw strokes
or the in-memory undo chain.

## Verification

Automated tests cover dense jitter, duplicate samples, minimum segment filtering,
square/rectangle/L/U/T topology, intentional curves, open irregular outlines,
disabled recognition and invalid input. Widget tests cover prompting only after
release, temporary previews, explicit acceptance, original retention, sketch
discard, gesture cancellation, undo/redo, fast single walls and shared anchors.
Existing drawing, document, annotation and calculation regressions also pass.

Requested scenario coverage (automated, not physical-device testing):

| Scenario | Result |
| --- | --- |
| Shaky straight line | Pass; commits one wall/two corners and remains editable |
| Rough square | Pass |
| Uneven rectangle | Pass |
| L-shape and meaningful corner | Pass |
| Irregular polygon | Pass; not coerced into a preset |
| Open unfinished outline | Pass; remains open |
| Continuous many-corner stroke | Pass |
| Very short/stationary input | Pass; no accidental wall |
| Keep Original | Pass |
| Accept, undo original preview, redo refinement | Pass |
| Avoid hundreds of permanent points | Pass; dense jitter reduces to endpoints |
| Existing connections and exact dimensions | Pass |

Native device finger/stylus accuracy and extremely long interactive sessions
have not been physically tested. The existing open native drawing is not reset
for testing; use a separate debug target when history representation changes.

Final verification: 263 automated tests pass. Analysis reports no errors or
warnings and 67 existing informational lints. An isolated headless Chrome debug
session compiled and hot-reloaded without reported runtime errors, then was
stopped. Save/reopen tests confirm pending sketch recovery cannot overwrite a
saved document; only canonical refined geometry is restored on reopening.

## Free-Drawing Intent Regressions

The model contains walls and shared corners, not automatically created room
objects. A continuous stroke is reviewed/committed as one operation; crossing
outside an existing outline does not start another sketch. At an actual
intersection, same-floor wall segments split into a shared junction. This is
not an overpass/non-connecting annotation tool.

Automated regressions cover near-closure acceptance/rejection and Undo/Redo,
near-returning irregular polygons, open and collinear returns, self-crossing
ambiguity, disabled recognition, crossing outside an existing room in one
stroke, unchanged original corner positions, extending boundaries, shared
crossings, duplicate segments and an independent second outline. Clear closed
outlines, partitions and cancellation remain in the existing suite. Physical
phone freehand/stylus usability is not verified by these automated tests.
