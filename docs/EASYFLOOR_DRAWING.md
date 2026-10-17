# EasyFloor Drawing Engine

## Active implementation

BuildCalc Home opens `lib/features/easy_floor/ui/easy_floor_screen.dart`.
The old imported package in `packages/easy_floor/` is retained as reference;
its room-path editor is no longer the active EasyFloor screen.

The current feature is exclusively a drawing workspace. It does not calculate
room areas or provide doors, windows, saving or exporting.

## Geometry

`DrawingPoint` stores real-world coordinates in millimetres. It and the connected
`WallNetwork` model contain no Flutter widget or canvas imports. Walls reference
corner IDs; adjacent walls use the same corner object identity via those IDs.
The UI converts between millimetres and screen coordinates using a camera origin
and pixels-per-millimetre scale. Zoom changes the camera, not wall lengths.

Drawing supports a straight single segment or a continuous outline stroke.
Stroke simplification removes small deviations while retaining meaningful
corners and diagonals. Endpoints snap to corners or projections onto walls.
Crossing walls and partitions split existing segments at shared junctions;
overlapping boundaries reuse the same wall segments. Open, closed, independent
and connected layouts are supported without forcing rectangle geometry.

## Editing

- Move wall: drag in any direction to translate it without changing its length or angle.
- Drag length: select this option in the wall inspector, then drag along the
  selected wall to resize its length with the starting corner anchored.
- Move corner: drag one corner, updating all walls connected to that corner.
- Enter length: type an exact dimension in mm, m, ft or inches.
- Room width / length: available on a four-wall rectangular loop.
- Delete: remove a selected wall, or all walls incident to a selected corner.
- Undo/Redo: retains 50 completed drawing edits during the current session.
- Pan: drag the camera; two-finger pinch is available in all tools.

Changes affect selected corners and their connected walls. Unconnected geometry
is left untouched. Normal exact entry does not add a lock, and preserves a
four-sided rectangle. Lock length / Unlock length is directly accessible in the
selected-wall inspector, with a matching lock-state icon. It does not move the
wall when enabled; direct wall dragging and ordinary exact length changes require
unlocking first. Unlock is immediate and both actions are undoable.
The existing constraints fix measured lengths, not absolute world positions;
connected/group edits that preserve those lengths retain their existing rules.
If an edit violates a fixed
measurement or collapses a wall below 10 mm, the edit reports a conflict.
Transactions roll back rather than partially applying an invalid edit.

A fixed wall that is split by a partition retains a total measured span. Its
subsegments do not acquire unnecessary individual locks. A junction can slide
along that span while its measured total remains fixed.

## Junction Measurements

Dimensions always use each wall record's own endpoints and length. A 12 ft
boundary with a 6 ft partition at its midpoint contains two 6 ft boundary
segments and one 6 ft partition, all sharing one junction corner. Straight-run
membership is derived for connected movement; it does not replace segment
measurements or create duplicate boundary walls.

At rest, selecting one segment highlights only that segment. During a straight-run
drag, the complete moved run is highlighted and each of its segments retains its
own contextual measurement, along with adjoining walls whose lengths change.
Active dimension leaders use the active-wall color. The existing label layout
avoids corners, wall geometry and other labels, and uses leaders for association.
Crowded lower-priority labels may be omitted rather than placed ambiguously.

A label on part of a locked continuous span says **Part of locked span** after
the segment's own length; it never substitutes the combined fixed total. A
single locked segment is marked **locked**. No extra overall-length overlay is
added to the canvas.

`junction_measurements_test.dart` covers midpoint T-junctions, cross/angled
connections, shared room boundaries, reversed duplicate strokes, span locks,
edits and history, crowded short segments, all six units at three zoom levels,
and segment selection/straight-run drag feedback. These automated checks do not
replace physical-device validation.

## Rendering And Gestures

The canvas uses one scale recognizer for drawing, editing, pan and pinch. There
is no competing pan recognizer. The first touch is recorded before the gesture
threshold, and a short accepted movement is applied at gesture start. Changing
from one to two fingers cancels the pending geometry edit before zooming.
The existing tap and scale recognizers are bound explicitly so drawing intent
uses a consistent threshold rather than device-dependent defaults. One-finger
geometry edits wait for 8 logical pixels of displacement (configurable through
`EasyFloorScreen.drawingMovementThreshold`, not another toolbar setting). The
threshold is independent of camera zoom and physical pixel density. The final
wall preview must also span at least that screen-space path length; a single
wall dragged outward and returned to a tiny result is not committed. Geometry's
existing 10 mm minimum remains separate. Preview geometry is never committed on
pointer cancellation, multi-touch navigation or app inactivity. No confirmation
is added for ordinary straight walls; existing freehand refinement is unchanged.

`accidental_drawing_test.dart` covers taps/jitter with touch, mouse and stylus at
1x/3x pixel density, short strokes at three zoom levels, a configurable threshold,
preview-only drawing, cancellation, second-finger/app interruptions, selection,
toolbar/dialog isolation and Undo/Redo. The 8 px default has automated coverage;
physical-phone threshold tuning remains unverified when no phone is connected.
Dimension inspectors overlay the canvas, avoiding coordinate jumps from layout
changes. Controls and inspectors scroll within bounds on small viewports.

Existing walls have screen-sized dimension labels. Label placement tries both
sides and multiple offsets, avoiding occupied labels and wall segments. They can
also shift along the wall and reserve current annotation bounds. Placement uses
the visible portion of partially off-screen walls, but the measurement always
uses the full real-world wall length. Entirely off-screen walls have no edge label.
Text remains horizontal and screen-sized for vertical/diagonal walls; distant
placements use subtle leader lines to show ownership. Dense
layouts may omit non-selected labels until zoomed; the selected wall's exact
dimension remains available in the inspector. The active stroke displays length
and direction. Display rounding never changes stored geometry.

Overview labels suppress only geometrically unambiguous duplicates: isolated,
unbranched rectangles show one dimension per pair of opposite walls, and squares
show one dimension marked `All sides`. Equality uses actual lengths, not rounded
unit text. Independent rooms are treated separately. Irregular outlines,
partitions, shared-wall components and fixed dimensions retain segment labels.
Selected walls and all walls affected by an active corner/resize remain eligible
individually. Visible representatives are preferred when panning; the existing
near-wall collision-aware placement still applies. Hidden labels do not remove
geometry or prevent selecting a wall and editing its exact dimension.

`smart_measurement_labels_test.dart` covers rotated rectangles/squares at three
zoom levels, equal-but-unrelated segments, irregular shapes, partitions, shared
walls, locks, selection/editing, off-screen representatives and exact entry.

## Limits And Checks

Walls must remain at least 10 mm long. Exact lengths are limited to 10,000 m;
coordinates are limited to +/-100,000 m. These are application bounds rather
than construction recommendations. Lengths alone do not determine every angle
of an irregular building; the sketch retains its geometry while dimensions are
edited. No sensor-derived measurement is implied.

Tests cover L/U/T outlines, stylus and touch input, world/screen conversion,
partitions and shared boundaries, junctions, overlap reuse, independent geometry,
locked spans, transaction rollback, rectangle dimensions, drag resizing,
undo/redo, pinch invariance and enlarged-text mobile/landscape layouts.

Real Android/iOS stylus and multi-touch performance still require device checks.

## Smart Touch Priorities

Automatic drawing/editing is the default and remains active after choosing Single
wall or Freehand. Those choices set the stroke style, not an exclusive drawing
mode. There are no separate Smart touch, Move wall or Move corner buttons.
Text and one-finger Pan are optional toggles; tap either again to return to
automatic drawing. Two-finger navigation always remains available.

1. Two fingers override the pending one-finger edit, restore its starting geometry,
   and navigate the camera until all fingers lift.
2. Text and its resize handle retain their independent annotation interactions.
3. A visible dimension label targets its wall; its extra 6-pixel touch padding
   never overrides a touch directly on visible wall/corner geometry.
   Tapping opens exact input; dragging moves that wall, not a new stroke.
4. A corner within 22 logical pixels normally wins outside the wall-body band.
   The full wall body uses a two-sided 16-pixel band. Endpoint cores remain for
   corner dragging, capped at 6 pixels or 20% of the wall's screen length. This
   keeps short walls selectable without taking away their exact endpoints.
5. A wall body within 16 pixels targets the closest segment. Exact distance ties
   for walls or corners use the lowest stable ID, independent of map order.
6. Empty canvas draws the chosen stroke style. Hold still on geometry for 450 ms
   before dragging to start a partition from it. Moving more than 6 pixels cancels
   this hold before the platform's drag threshold; slow edits cannot become drawing.

Touch-down highlights the target without modifying geometry. Gesture recognition
uses the original touch-down location and the platform movement threshold. The
same resolved wall/corner is used at drag start; drawing never changes to moving
because the finger later enters a wall's touch zone. Tapping a wall selects its
inspector. Touch tolerances are converted to world units at the screen boundary.
Two-finger pan/zoom is available without leaving automatic editing. The existing
Cancel action restores an active edit; completed operations retain Undo/Redo.
Hide UI does not change these priorities or automatically reopen the tools.

## Wall Movement Constraint Rules

- Translate the entire connected collinear wall run by the full finger
  displacement, including intermediate partition junctions. Its lengths and
  direction remain unchanged. No disconnected wall is included.
- Shared corner IDs move once; attached non-collinear walls stretch from their
  unchanged far endpoints. There is no global room solver or automatic remote
  reshaping. Corner dragging deliberately permits irregular angles.
- Exact single-wall input anchors its start and moves its end along its existing
  direction. Rectangle width/length input preserves the four right angles.
- Fixed measured spans, 10 mm minimum edges and coordinate limits are checked
  atomically. Newly crossing or overlapping walls are rejected during edits;
  deliberate newly drawn partitions still split into shared junctions.
- Snap/join occurs on release. Invalid requests show a reason, not an automatic
  unlock or hidden change to another constraint. Drag previews are transient;
  only completed valid edits enter history. Cancel restores the starting state.

The model uses explicitly assigned millimetres and a pixels/mm camera; these are
plan dimensions, not physical measurements inferred from a phone or photograph.

### Update Verification

Automated geometry/widget coverage includes: shared two-room wall movement,
exact rectangle dimensions, L-corner reshaping, unrelated-wall invariance,
partition joins, corner hit priority, explained fixed-span conflicts, complex
undo, camera-scale-independent edits, twenty repeated connected-wall edits,
collinear junction preservation, overlap rejection and dimension-label tapping.
These tests are not physical Android/iOS finger or stylus certification.

## Natural Drawing Update

In automatic editing, hold a corner or wall for 450 ms, then drag to draw a new wall
from it. A connection crosshair indicates the anchor. Immediate dragging still
edits the existing geometry. Two fingers cancel the hold/drawing intention and
navigate. Single wall and Freehand both retain this automatic behavior.

The existing toolbar keeps Text, Pan, Single wall and Freehand accessible.
Single wall draws one straight segment per drag; Freehand preserves the outline
and refinement workflow. Either option returns from Text/Pan to automatic
drawing and editing, without a separate editing mode. Shapes opens the preset
grid; More contains Drawing help, Cancel and drawing assistance. Documents and safe switching are described in
[EasyFloor Documents](EASYFLOOR_DOCUMENTS.md).

Drawing assistance (the toolbar tune icon) provides:
- Horizontal / vertical alignment: enabled initially to help reach 0/90/180/270
  degrees. The 15-degree increments option remains disabled initially.
  Angular assistance uses the selected tolerance (3 degrees by default) as well
  as a zoom-converted screen-distance limit. Parallel / perpendicular assistance
  is independently optional. A real endpoint snap takes priority over alignment.

Basic endpoint connections are always enabled, independently of optional
alignment assistance and older saved snapping preferences. The touch tolerance
is 16 logical pixels converted through the camera scale to mm. The nearest
eligible endpoint or wall projection wins; adjacent endpoints that would
collapse a wall are excluded. Corner drags show the existing connection target
indicator, and release reuses a shared corner or splits a wall at the junction.
Constraint conflicts reject the edit; Undo restores the pre-connection geometry.

The displayed preview is committed as-is, without a second release-time snapping
pass. Open strokes stay open unless the user returns within 4 logical pixels of
their starting point with snapping enabled. No room recognition or rectangular
coercion occurs. Undo/redo and pointer cancellation remain available.

## Repeatable Drawing Checks

Use these manual cases on Android/iOS with finger and stylus. The geometry and
widget tests automate the corresponding operations, but do not replace hardware
latency, palm-rejection or touch-accuracy testing.

| Scenario | Actions | Expected |
| --- | --- | --- |
| Rectangle | Draw four sides continuously, return to start | Four shared corners |
| Connected rooms | Hold top boundary, draw to bottom; repeat twice | Shared T-junctions, no duplicate boundaries |
| L with partition | Sketch an L; hold its top wall and draw across an arm | Outer notch retained, shared partition endpoints |
| U/T building | Trace each outline continuously | Re-entrant corners retained |
| Angled layout | Draw diagonal walls with alignment off | Angles retained |
| Narrow corridor | Trace a narrow corridor and add branch walls | No rectangle coercion or forced widening |
| Midpoint join | Draw from empty space to middle of a wall | Existing wall splits at shared corner |
| Unfinished plan | Stop near but over 4 px from the first point | Outline remains open |
| Different zoom | Pinch, then draw/edit a known wall | Length uses mm, not changed camera scale |
| Repeated edits | Slide shared wall and reshape a corner, undo/redo | Connected IDs and unrelated geometry retained |
| Long stroke | Trace a zigzag with dozens of corners | Intentional segments retained; one undo removes stroke |
| Exact correction | Tap a wall label, enter length; also edit rectangle dimensions | Exact geometry or an explained fixed-length conflict |

Additional gesture regressions cover snapping disabled, visible connection
feedback, hold-to-continue, active stroke cancellation, and preserving the exact
preview on release. Dense label placement and drawing beyond 4096 raw samples
still use the existing simplification/decimation policy; very dense plans should
be zoomed in before editing.

## Temporary Guides And Context Measurements

Temporary guides are display-only `DrawingGuide` values, never wall segments or
history entries. A pure Dart candidate selector considers horizontal/vertical
alignment to corners and the active anchor, straight wall extensions, and
parallel directions. Tolerance is 6 logical pixels converted to mm at the current
zoom. At most two different directions are shown, ranked by proximity with a
small retention preference for the current target. Duplicated parallel guides
are suppressed. Guides disappear when irrelevant, on release, cancellation,
constraint failure or two-finger navigation. Guides are informational; they do
not enable snapping or alignment assistance automatically.

The painter renders thin dashed lines and subtle target rings. Opacity defaults
to 0.5 and can be configured through `EasyFloorScreen(guideOpacity: ...)` between
0 and 1. Styling uses the shared palette.

Measurements are contextual by default:
- Idle unselected plan: individual segment labels are on by default for new plans;
  Hide labels and saved visibility preferences are respected.
- Selected wall: its length and existing editing controls.
- Drawing: only the live final segment length, with angle context for relevant
  parallel/extension guides.
- Moving wall: its current length and displacement from its starting position.
- Moving corner: lengths of directly attached walls during the gesture.
- Navigation: all-wall labels remain visible when enabled; transient guides are hidden.

The Drawing assistance menu can explicitly enable Show all measurements.
Drawing/navigation still suppress unrelated labels. Labels reuse valid previous
normal offsets and avoid other labels, walls, corners, notes, the finger and snap
target. Show all measurements yields to affected walls during wall/corner edits
and returns after release. Units omit padding zeros; millimetres display up to one
decimal and other decimal units up to two, without rounding the stored geometry
or numeric input. Feet/inches retains its existing tenth-inch display precision.
When there is no collision-free position, a lower-priority label is omitted;
selected wall dimensions remain available in the inspector. Pixel positioning
and display rounding do not change real-world geometry.

Regression coverage includes display-only guide selection, competing targets,
zoom tolerance, angled extensions/parallel references, contextual visibility,
wall displacement, corner attachments, guide lifecycle/cancellation, collision
avoidance, stable label offsets and selected-label dimension entry.

## Shape Cleanup And Presets

Shape recognition is enabled in Drawing assistance and can be disabled there. It is
conservative, local recognition, not room detection: closed near-orthogonal
four-corner outlines can suggest squares or rectangles; near-orthogonal
six-corner L outlines retain their notch. Eight-corner near-orthogonal U/T outlines
retain their re-entrant corners, with conservative topology and correction checks.
Triangles already have straight sides
after stroke simplification and are recognized without inventing equal angles.
Open outlines remain open; irregular shapes are simplified without preset coercion. A gesture
whose vertices already touch existing walls is not reshaped by recognition.

The original stroke stays visible as a thin translucent trace while drawing.
A finished freehand outline asks once: "Straighten and refine this sketch?"
Keep Original commits its conservative polyline. Yes, Straighten shows a temporary
preview, followed by Accept refinement or Cancel refinement (retains the original).
Discard sketch removes only the pending sketch. Refinement Undo restores the
original preview, Redo restores refined walls, and a second Undo removes the
sketch. Keep Original is one geometry edit. Individual single-wall strokes bypass the review. Cleanup checks
edge lengths, unique connected topology and correction limits instead of forcing
every outline into a preset. See [Sketch Refinement](EASYFLOOR_SKETCH_REFINEMENT.md)
for point-reduction behavior and limits.

Commands that commit shape/group edits are unavailable during an unfinished
gesture. The wall inspector reappears after release; canvas dimensions remain
contextual during the drag. Opening Clear plan cancels any unfinished gesture
before asking for confirmation. If reconnection replaces selected segment IDs,
the selection is cleared with an explanation rather than guessing new targets.
See [Complete Drawing Board Audit](EASYFLOOR_COMPLETE_AUDIT.md) for architecture,
workflow coverage and physical-testing limitations.

Shape presets include Square, Rectangle, right Triangle, L/U/T shapes and
Freeform polygon. Enter dimensions in the workspace's current units and a
clockwise rotation in degrees. Tap the canvas to position a draft at its first
corner; drag to set its width and height in its rotated axes. The dimensions /
rotation action refines the draft numerically. Place shape creates ordinary
shared wall geometry. Draft anchors can snap to existing geometry; intersections
and overlaps use the existing junction/deduplication engine. U/L/T presets use
fixed initial notch proportions; their individual walls/corners remain editable
after placement. Subsegments below 10 mm are rejected with an explanation.
Freeform polygon uses tapped vertices and an explicit Finish polygon action.

## Angle And Unit Definitions

Live wall direction is clockwise from the canvas's right-facing horizontal
axis, normalized to 0–360 degrees (canvas Y increases downward). Corner arcs
show the smaller included angle between two connected wall vectors, 0–180
degrees: right angles are 90 and collinear opposite directions are 180. These
are not claimed to be detected room-interior/reflex angles. At multi-wall
junctions at most two relevant pairs are displayed. No unrelated idle arcs are
shown. Shape previews also display the relevant last corner angle.
Labels explicitly distinguish `Dir` (absolute direction) from `Corner`
(included angle). A new two-point stroke starting at an existing endpoint or
wall midpoint can display its connected angle before geometry is committed.
Parallel/perpendicular guide labels say `Align 0°` / `Align 90°`: these describe
the guide target, not a claim that a nearby unsnapped wall has that exact angle.

The workspace unit setting applies to labels, offsets, previews, presets and
exact input. Changing it in the dimension dialog updates the same setting.
Internal coordinates remain mm. Feet and inches are displayed to 0.1 inch with
carry into feet; exact entry accepts two components, e.g. `11 5.8` or
`11 ft 5.8 in`. Inches must be below 12, and negative/non-finite/out-of-range
lengths are rejected. Other existing display precisions are preserved. Display
rounding never writes back to geometry; numeric editing deliberately does.
This is a scaled plan, not an inferred sensor measurement of the building.

## Whole-Plan Actions

Plan actions provides Select all and Clear plan. Select all highlights walls and
annotations; Delete removes the whole selection in one paired history operation.
Single walls/corners expose Delete in their existing contextual controls; group
deletion uses the floating palette. No selection means no contextual Delete.
Clear plan requires confirmation. Both deletion paths are undoable, including
shared junction IDs and fixed measured spans. Units and assistance settings are
not deleted. The geometry model has no layers, so no layer system is introduced.

Tests cover recognition accept/retain choices, proportions, irregular rejection,
notch topology, presets/rotation/drag placement and shared boundaries, exact
entry in all six units, feet/inches carry, 90/180/diagonal included angles,
select/delete/clear confirmation and connected-geometry undo. Physical touch,
stylus and dense-angle-label readability still require target-device checks.

## Reliability And Safe Editing

Split wall is available in the selected-wall inspector. Enter the distance from
its starting corner in the current unit; both resulting parts must be at least
10 mm. Splitting a fixed measured span preserves its total constraint. Select
a degree-two corner and use Join straight segments to remove that intermediate
corner. Only opposite, collinear segments can join; branch junctions and
individually incompatible length locks produce explicit conflicts. Joining does
not silently discard a fixed measured span.

Corner dragging reconnects to endpoints or wall midpoints using the existing
snap/junction engine. Coincident connections become shared IDs on release.
Full-direction translation preserves length and direction. A wall split by
collinear junctions moves as one connected straight run in automatic touch
editing. The affected run is highlighted on selection; adjoining walls retain
shared corner IDs. Unrelated or disconnected walls do not join the movement.
The workspace has no manual straight-run toggle; automatic wall movement uses
the connected run consistently.
The latest [professional workflow audit](EASYFLOOR_PROFESSIONAL_AUDIT.md) covers
closest-target snapping, padded-label target conflicts, the continuous acceptance
sequence and verification limits.

## Drawing Guidance

An empty automatic-editing canvas shows a short, non-interactive drawing hint.
It disappears as soon as the user starts interacting, when geometry or notes
exist, during shape review, and in Hide UI mode. It neither reserves canvas space
nor intercepts touches.

Drawing help is available in the existing More drawing tools menu. Its temporary,
scrollable sheet explains sketching, direct editing, exact dimensions, holding
an existing wall to start a partition, refinement choices, navigation, recovery,
and hiding the interface. Closing help retains the current tool, camera, geometry
and selection. It adds no permanent toolbar or onboarding workflow.

Automated coverage checks drawing through the empty hint, Hide UI behavior,
unchanged geometry/camera after help, and scrollable help at 240 x 420 and
740 x 320 with 1.8x text. Physical-phone usability remains unverified.

[Wall movement verification](EASYFLOOR_WALL_MOVEMENT.md) records the two-sided
hit-band repair, side-drag matrices and outstanding physical-mobile checks.

## Simplified Controls

Tap a closed shape's empty interior to highlight its connected wall network;
drag there to translate it rigidly. Closed-face detection uses shared wall
topology and handles concave outlines and partitions without creating room
objects. A shared boundary selects all connected rooms/branches, not an arbitrary
subset that would stretch the neighbouring room. Wall/corner/label/text touches
retain priority. Open outlines still draw normally; use hold-to-draw from an
existing boundary when adding a partition.

Whole-shape moves preserve length constraints, corner IDs and annotations as
separate objects (notes do not move with walls). Gentle single-axis alignment
uses a six-logical-pixel tolerance converted through zoom. A snap that would
cause contact/overlap is discarded in favour of the valid raw translation.
Separate rooms never automatically merge during this operation: touching,
crossing or containing independent geometry is rejected atomically. Use existing
endpoint editing for an intentional junction. Cancellation and pinch interruption
restore the starting geometry; each completed move is one Undo/Redo operation.

The upper-left Plan axes overlay provides fixed N/S/E/W directions, independent
of camera origin, zoom and geometry. It remains visible at the same screen
position when Hide UI removes the header. It is touch-transparent and has no
model state, snapping targets or sensor connection. North is a plan reference,
not configured geographic North. Its text follows system text sizing; error
feedback is placed below it rather than obscuring the reference.

Normal wall selection shows its measurement, Lock/Unlock, Enter length and Delete. The
optional Room width / length shortcut and existing precision/constraint controls
are grouped inside the collapsed More wall options section. Ordinary corners
show Delete; Join straight segments appears only at a degree-two straight
corner, with final constraint validation still enforced by the engine.
Undo/Redo and Cancel remain in the existing palette. Hide UI and palette
position/collapse state are unchanged. Tests now exercise direct wall/corner
selection rather than selecting removed manual modes.

Physical-phone checks remain deferred by user request. Automated mobile-size
coverage is not a substitute for manual finger testing.
