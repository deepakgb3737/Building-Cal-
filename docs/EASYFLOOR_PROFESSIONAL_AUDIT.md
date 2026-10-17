# EasyFloor 2D Workflow Audit

## Interaction References

Reviewed official [RoomSketcher drawing guidance](https://www.roomsketcher.com/features/draw-floor-plans/)
for exact measurements in an editable plan, and [magicplan room assembly guidance](https://help.magicplan.app/assemble-your-rooms-to-a-floor-plan)
for direct dragging with visible connection feedback and dimension editing.
These are interaction references, not a claim of feature parity or certification.
The existing connected-wall engine and floating toolbar were retained.

## Defects Reproduced And Fixed

1. Snapping returned a nearby corner before checking whether a wall projection
   was closer. A finger directly on a wall could jump to an unrelated endpoint
   nine logical pixels away. The shared engine now compares eligible corners
   and wall projections by distance. Equal-distance corners retain priority;
   same-kind ties use stable IDs. Own-neighbour/collapse exclusions remain.
2. The six-pixel padded target around a dimension label could cover the wall
   itself. After exact entry, holding the selected wall then dragging moved the
   wall instead of starting a partition. Actual label bounds still open exact
   input; padding only applies away from visible wall/corner targets. The same
   helper is used by touch-down, tapping and gesture initiation.

The new tests failed against the previous implementation and pass with the
fixes. No geometry format, calculation formulas, toolbar layout, new tool modes,
or document format changed.

## Acceptance Results

All rows below are automated widget-test results from one continuous workflow,
without switching drawing/editing modes:

| Scenario | Result |
| --- | --- |
| Draw a connected rectangular room | Pass |
| Drag a side, keep the opposite side fixed, show changing lengths | Pass |
| Tap the dimension and apply an exact room width without a lock | Pass |
| Hold an existing wall and draw a connected partition | Pass |
| Move an outer corner; unrelated corner stays unchanged | Pass |
| Delete one wall; Undo restores exact geometry; Redo removes it again | Pass |
| Continue drawing another wall without selecting a mode | Pass |

Additional regressions verify competing snap targets at 0.02, 0.1 and 1.0
pixels/mm, stable ties after changing map order, and existing neighbour-collapse
protection. The full suite covers irregular outlines, shared corners, locks,
intersections, cancellation, zoom, deletion, annotations and Hide UI.

## Verification And Limits

- Full Flutter suite: 363 tests passed.
- Analysis: no errors or warnings; 65 existing informational lint notices.
- Isolated Chrome debug compilation and hot reload verified.
- Device discovery: macOS and Chrome available; no Android/iOS test target.
- No physical-phone usability, touch-latency or accessibility verification.

Existing dense-layout debug benchmark, median of five samples on the development
Mac (milliseconds, not device frame-rate guarantees):

| Walls / Corners | Snap | Corner preview | Junction finalization | Paint |
| --- | ---: | ---: | ---: | ---: |
| 60 / 36 | 0.066 | 0.241 | 0.575 | 1.233 |
| 220 / 121 | 0.099 | 0.644 | 0.677 | 2.497 |
| 840 / 441 | 0.078 | 0.901 | 3.193 | 3.017 |

These timings exclude physical input/display latency and do not establish mobile
performance. Exact rectangle preservation targets four-sided rectangular loops;
complex constraints are rejected when incompatible, not solved by moving
unrelated geometry. Dense labels may still be omitted when no readable position
is available. No claim of perfect behavior on every layout or device is made.
