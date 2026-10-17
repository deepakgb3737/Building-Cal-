# EasyFloor Text Annotations

## Using Text

- Choose **Text**, then tap the canvas to create a room name, letter or note.
- Enter multiple lines if needed. Blank/whitespace-only text is rejected;
  each object permits up to 2000 characters.
- Choose size, one of five named theme colors, and left/center/right alignment.
- Tap existing text in Text or Smart touch mode to edit. Cancel keeps its previous
  content and formatting. The modal editor blocks drawing until dismissed.
- Drag text to move it. Its selection outline and four small corner markers make
  the active object clear. They indicate selection; they are not resize handles.
  Font size is changed in the editor.
- The text inspector provides Edit, Duplicate and Delete. Copies retain content,
  color, size and alignment and are offset by 24 logical pixels at the current zoom.
- Enable **Select texts**, tap notes to toggle selection, then drag selected text
  together or duplicate/delete it as one operation. Blank taps clear selection in
  this mode instead of adding text. Wall multi-selection remains separate.
- Undo/Redo restore text and walls in chronological order. A text drag is one edit,
  not one history entry per movement update. Cancel/pinch restores the pre-drag note
  positions. Clear plan confirms removal of both walls and text and is undoable.

Text can be inside or outside any outline, including on a text-only canvas. Pan,
pinch and Fit to Screen also work when there are no walls.

## Geometry And Interaction Boundary

`logic/drawing_annotations.dart` owns independent immutable annotation values and
a validated layer. Its map is read-only to callers. Text never enters wall
intersection, dimension, snapping, angle, or constraint calculations.

In Smart touch/Text modes, text hit targets take priority over underlying walls.
Explicit Draw wall/Move wall/Move corner tools still target geometry. Text-only
group selection does not select walls or corners. Text guides are temporary and
display-only, using nearby note anchors, wall/endpoint alignments and the viewport
center; displaying one never reconnects or changes walls.

Annotation positions use the same canonical millimetre coordinate system and
camera transform as walls. Moving/panning/zooming text does not alter wall data.
Wall-only group operations/calibration do not implicitly move or resize text.

The canvas exposes note contents and edit actions as semantic targets. Duplicate
and Delete have named tooltips. Formatting uses existing AppColors/AppTypography.

## Size And Zoom

The size control ranges from 12 to 48, defined at the workspace's nominal 100%
camera scale of 0.1 logical pixels/mm. Internally size is stored as 120-480
canvas millimetres, not as an independent screen-pixel position.

Text layout uses a 240-logical-pixel maximum line width at nominal zoom. The
completed layout scales with the camera, so zoom does not rewrap paragraphs or
change stored formatting. User-entered newlines remain intact. Display size now
scales proportionally at every zoom so the full annotation can fit an overview;
zoom in to read small overview text. Position stays world-anchored and the
nominal stored size does not change. Selected text exposes a bottom-right drag
handle for changing its nominal size without changing wall geometry. These labels are
annotations, not physical measurement claims.

## History And Implementation

`DrawingHistory` snapshots both the wall model and the annotation layer. Existing
wall callers still use `commit(model)` and retain the last annotation snapshot.
Annotation changes call `commit(model, annotations: layer)`. Undo/Redo return the
wall snapshot as before; the UI also restores `history.annotations`.

The common history retains the latest 50 edits. The later document-management
update saves annotations with the wall graph and settings; reopening starts a
fresh paired history. See [EasyFloor Documents](EASYFLOOR_DOCUMENTS.md). Export and
backend services remain outside scope.

Rendering/dialog/controls are in `ui/annotation_painter.dart`,
`ui/annotation_dialog.dart`, and `ui/annotation_controls.dart`. Selection bounds
come from the actual rendered text layout. Inspector controls are an overlay,
not a layout-changing panel that could move the canvas under a dragging finger.

## Automated Verification

`annotations_test.dart` covers validation, atomic group failures, read-only
access, repeated movement, formatting-preserving duplication, combined history,
proportional display sizes, stable wrapping and semantic edit targets.

`annotation_interaction_test.dart` covers actual tap/drag/edit workflows,
multiline formatting, apply/cancel, wall overlap, group movement/copy/delete,
temporary guides, pinch rollback, undo/redo and clearing/restoring a mixed plan.
It also checks 240x420 and 740x360 layouts with 1.6x system text scaling.

Full-suite verification: 220 tests passed, including 14 annotation tests. Analysis
reported no errors/warnings and 69 existing informational findings. The macOS debug
build succeeded; native visual inspection was blocked by the locked Mac.

Synthetic gesture and layout tests do not establish physical Android/iOS touch
behavior, stylus feel, native keyboards or long-session performance. Color choices
are a fixed five-color palette, not an arbitrary-color picker. Text supports
left-to-right paragraph direction; full bidirectional text editing is not verified.
