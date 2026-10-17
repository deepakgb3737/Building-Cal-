# EasyFloor Navigation And Resizing

Updated 2026-10-15. Existing wall editing, snapping, dimensions, annotations,
shape presets and document workflows are retained.

## Controls

- **Single wall / Freehand** remain drawing tools. Empty-space drags in these
  modes still draw rather than unexpectedly moving the viewport.
- **Pan** is directly available on the second toolbar row. One
  finger moves the camera, including near walls/text, without editing objects.
- Two fingers pan and pinch in drawing/editing modes. Zoom is anchored to the
  actual finger midpoint; it does not change dimensions, text data or wall IDs.
  Touch navigation begins when the second finger lands, so small pinches do not
  wait for the scale recognizer's drag threshold. The recognizer cannot restart
  the same raw-touch navigation snapshot. Native trackpad pinch uses its own
  camera/anchor baseline rather than stale touch-pointer state.
- **Fit to Screen** is in the toolbar's top row. A double tap within 300 ms and
  24 logical pixels also fits, but only on empty canvas. Text, wall, corner,
  dimension-label, polygon/preset and pending-review interactions are excluded.
  Normal text taps still edit immediately without a double-tap recognizer delay.
- Selected text has a larger bottom-right resize handle. Drag it to adjust the
  existing nominal 12-48 size range; other text drags move the annotation. Text
  positions, formatting and geometry stay independent. Resizing is undoable.
- Shape presets have an opposite-corner handle that preserves their anchor while
  resizing. Existing drag-from-another-point placement/resizing still works.
  Rotated presets resize in local axes; squares preserve equal sides. Dimensions
  update live, and geometry is committed only with Place shape.
- In Smart touch, wall endpoints/corners continue to resize connected geometry;
  wall middles move parallel. The existing Drag length / Enter length inspector
  remains available. Locked dimensions still reject incompatible changes.

## Camera And Bounds

`logic/drawing_camera.dart` fits world-space bounds to the current canvas with
uniform scale, centering and a nominal 32-pixel margin (adapted for tiny
viewports). Empty/zero-sized canvases are no-ops. Camera scale limits are shared
with document validation: `1e-7` to `2`, allowing overviews beyond the previous
`0.005` lower bound without modifying plan geometry.

`annotationTextLayout` is shared by annotation rendering and world-bounds
measurement. Fit includes every note's complete measured rectangle, including
multiline and negative-coordinate notes, rather than stale screen rectangles or
just text anchors. Individual wall/text inspectors are cleared; a remaining Text
tool panel is accounted for using its measured height.

Text wraps at its existing nominal layout width and scales proportionally with
the camera. The old minimum 8-pixel display clamp could make a long paragraph
physically impossible to fit; that clamp is removed. Overview text may be tiny;
zoom in for details. This never changes stored annotation size or content.

## Gesture Safety

Pointer positions provide the midpoint/span from the moment the second finger
lands, avoiding drift at the scale recognizer's movement threshold. Adding or
removing extra fingers rebases the navigation span, including an OS-cancelled
pointer when at least two touches remain. This prevents a stale three-touch
span from turning a subsequent two-finger pan into an unintended zoom.
The remaining finger cannot
resume drawing/editing after a pinch until all fingers have lifted.

A second finger rolls back active drawing, text resizing, wall/corner editing
and preset changes before navigation. Cancellation restores the starting
camera/objects. Completed pan/zoom operations never create history entries.
Pending sketch previews can be navigated without clearing their original data
or invalidating Undo/Redo. No resizing occurs while a text editor modal is open.

## Verification

Pinch reliability follow-up: `pinch_reliability_test.dart` reproduces the former
small-touch dead zone and trackpad anchor jump. Both now pass, along with
repeated pinch in/out, adding a second finger during drawing, cancellation and
subsequent drawing. The complete suite passes 316 tests; analysis has no
errors/warnings and 67 informational diagnostics. Physical pinch feel has not
been reverified: Android debugger attachment failed, and the existing phone
drawing was not restarted to force deployment.

Automated coverage includes:

| Scenario | Result |
| --- | --- |
| Pinch zoom in/out and moving midpoint | Pass |
| Remaining finger does not draw after pinch | Pass |
| One-finger Pan and cancellation | Pass |
| Empty-area double tap matches Fit control | Pass |
| Empty canvas does not change camera | Pass |
| Text taps open editing instead of fit | Pass |
| Large positive/negative plan bounds fit with margins | Pass |
| Long multiline/text-only annotation fit | Pass |
| Text handle resize, undo/redo, cancellation | Pass |
| Second finger interrupts text resizing safely | Pass |
| Preset handle keeps anchor and live dimensions | Pass |
| Restored sketch preview survives pinch and retains redo | Pass |
| Existing corner/wall resizing, constraints and competing targets | Existing regression suite passes |

These are synthetic unit/widget gestures, not physical-phone measurements.
Final checks: 276 tests pass; analysis reports no errors/warnings and 67 existing
informational lints. The isolated Chrome debug app compiled and hot-reloaded
without reported runtime errors. The existing native workspace was not reset.
Real Android/iOS finger/stylus behavior, extremely long interactive sessions and
very dense layout performance still require device testing. Very large/small
overviews cannot keep all text readable simultaneously; zooming is intentional.
