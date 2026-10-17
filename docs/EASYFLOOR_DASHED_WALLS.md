# EasyFloor Dashed Walls

## Usage

- Open the existing toolbar's Drawing assistance menu and choose Dashed wall
  or Normal wall. The Wall button reflects the chosen type.
- Drag to draw a single wall. Choose Draw for continuous freehand strokes, or
  place a preset; new walls retain the selected type.
- Select a wall, open More wall options, and choose Make normal or Make dashed.
  Conversion affects only that wall and is undoable, including on locked walls.
- Existing snapping, dimension entry, corner editing, wall movement, locking,
  deletion and Undo/Redo use the same connected-wall geometry engine.

## Geometry And Appearance

The immutable wall record stores a dashed flag, defaulting to false. Splitting,
copying, editing and sketch refinement preserve it. Conversion changes no IDs,
coordinates, connections, measured spans or constraints. Connected normal walls
are not restyled. Joining different styles is rejected with an explanation;
convert them to the same type before joining. Retracing an existing segment does
not change its style or create a duplicate wall.

Rendering uses an 8 logical-pixel dash and 6 logical-pixel gap, independent of
world scale. Offscreen portions are clipped before generating dashes. Locked
walls retain the shared red color, selection remains highlighted, and dimension
labels do not depend on the dash pattern.

## Persistence And Verification

Saved wall rows include an optional fifth boolean for dashed walls. Documents
without it load as normal walls. Pending sketch history also retains the chosen
type, so Undo/Redo cannot silently change a proposed sketch to normal geometry.
The choice for future drawing is a session preference, not a document setting.

Regression tests cover mixed-style junctions, overlap protection, splitting,
editing, duplication, locking, conversion, Undo/Redo, legacy documents, repository
save/reopen, complex outlines, toolbar actions and rendering at three zoom levels.
Physical Android touch behavior requires separate device verification.
