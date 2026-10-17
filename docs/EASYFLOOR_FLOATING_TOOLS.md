# Floating Drawing Tools

The drawing table no longer reserves a top tool panel or bottom help strip.
Tools sit in one floating palette above the canvas. In its normal two-row layout,
drag the collapse/expand icon to reposition it; collapsed and review panels retain
the dotted handle. Collapse reduces it to 96 x 48 logical pixels. Canvas bounds
and real dimensions do not change.

The expanded normal toolbar uses the available width (up to 760 logical pixels).
The first row contains Undo, Redo, Fit, More and Collapse. Cancel replaces More
during an active gesture, without adding a cell or changing row height. The second
row contains Draw (freehand), Wall (single segment), Shapes, Pan, Text and Labels.
Existing selected-wall/corner inspectors
provide Delete and Lock/Unlock; group controls retain Undo, Redo and Delete.
Drawing and selection remain automatic, without a separate Select/Move button.
Selected connected shapes also expose Delete with confirmation and Undo.
Contextual inspectors use the larger clear region above or below the palette;
they scroll when necessary rather than pushing the palette away. Only explicit
dragging, expansion/collapse or viewport clamping changes palette bounds.
Cancelling a toolbar drag restores its starting position. The compact tool-label
metrics and grid colors are shared UI tokens. The canvas has subtle major grid
lines and optional minor detail when spacing is large enough to remain legible;
these display-only lines do not change snapping or real-world measurements.

Shapes opens a single labelled grid containing Square, Rectangle, L-shape,
U-shape, T-shape, Triangle and Irregular Shape. Presets use the
existing dimension-entry and proportional-preview workflow. More contains drawing
assistance and Drawing help, not duplicate Cancel, label-visibility or preset controls.

At normal phone widths the toolbar has two tool rows. Very narrow windows or
large accessibility text wrap into additional rows with vertical scrolling when
required; no horizontal scrolling hides tools. Expanded tools occupy at most half
the canvas height, leaving contextual editing space on short screens. Touch cells target at least 48
logical pixels when space permits. Review, preset-placement and group workflows
reuse their existing compact panels and behavior. Pending reviews, presets and
group selections never expand the toolbar. Pending sketch and preset actions
appear temporarily in the existing contextual area while collapsed; collapsing
never discards the draft.

The toolbar stays independent of contextual-panel height. Inspectors fit around
its current bounds instead of reserving a bottom strip. Dragging is clamped to
the canvas, and rotation/window resizing clamp it back into view.
Position/collapse state is local to the workspace, not geometry history. Safe
areas and keyboard-resized canvas constraints remain owned by the drawing screen.

Expansion is changed only by the Expand/Collapse control. Drawing updates do not
reset it; Hide UI retains the mounted toolbar and restores its previous expansion
state. The preferred position is remembered between rebuilds and only clamped
when available space requires it. There is no drawing-driven auto-open listener.

Only palette bounds intercept input. Dragging or collapsing it cancels an
unfinished canvas gesture rather than accidentally committing walls. All canvas
outside it remains available for drawing, selection and two-finger navigation.
If the palette covers something important, move or collapse it; the app does not
move it continuously in response to wall movement. Contextual wall/corner/text
inspectors still appear only when relevant and retain existing controls.

Selected walls and corners expose a named Delete action in their existing
inspector, including when the palette is collapsed. Multi-selection and Select
all use Delete in the same palette. Delete is absent without a valid selection
and is blocked during canvas pointer activity, dragging or navigation. Text
Delete is likewise hidden without selected text. A connected corner still
requires confirmation before removing its attached wall segments.

Select all highlights both walls and annotations. Deleting the complete
selection removes both layers, including text-only drawings; Undo restores the
complete prior drawing in one operation. Deleting a single wall removes only
that segment, cleans unused corners and retains unrelated geometry and notes.
Regression coverage includes narrow portrait/landscape with 1.8x text scale,
single-wall Undo/Redo, whole-drawing and text-only deletion, hidden empty-state
actions and stale Delete callbacks during wall drag/pinch. These regressions
remain in the full test suite. Physical-phone deletion gestures were not tested
in this update.

Verification includes viewport bounds at 240 x 420, 740 x 320 and 320 x 640,
1.8x text scale, drag/clamping, collapse/expand with unchanged canvas size,
scrolling, undo history, camera/geometry isolation, active-stroke cancellation,
and new-sketch review visibility. Existing text and navigation tests now open
or collapse the palette explicitly when their workflow needs canvas space.
The browser layout and collapse interaction were inspected. Physical-phone
drag feel and platform accessibility behavior were not tested in this update.

## Distraction-Free Canvas

Hide UI in the header hides the header, floating palette and contextual panels.
Only the small Show Tools button, canvas measurements/guides and essential error
feedback remain. Show Tools restores the existing controls without recreating
palette position, collapse state, inspector expansion or selection. Drawing and
editing never automatically exit this mode. Pending sketch reviews remain in the
existing palette; restoring tools does not force a previously collapsed palette
open. Pending actions return to the contextual area if the palette is collapsed.

The canvas grows into the former header space. Camera translation compensates
for the header change, keeping the drawing at the same screen position without
altering geometry or adding Undo entries. If requested during an active canvas
gesture, the visibility change waits until all fingers lift or cancel, avoiding
a coordinate-frame change midway through drawing or pinch navigation. Hidden
inspectors do not consume touch input or reserve canvas space. This visibility
preference is local to the workspace and is not persisted in documents.

Automated checks cover restoration, active-drag completion and Undo, drawing
feedback, pending-review collapse state, and small portrait/landscape screens
with enlarged text. Physical-phone testing remains unverified.

`professional_toolbar_test.dart` verifies the two rows, touch targets, seven
shape choices, existing preset dialog, narrow/landscape bounds and large text.
Widget tests do not verify physical Android/iOS touch behavior.
