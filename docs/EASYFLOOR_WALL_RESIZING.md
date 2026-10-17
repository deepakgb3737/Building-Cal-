# Wall Resizing And Scale Dots

Normal editing needs no resize-mode or lock setup. Drag a wall perpendicular to
its direction to resize the adjacent room while keeping the opposite side still.
The dragged wall and adjoining walls whose lengths change have live dimensions.
Tap a dimension (or Enter length) to apply an exact size: four-sided rectangular
rooms retain right angles, the endpoint-A side stays fixed, and the opposite
parallel side updates with it. Other outlines resize the selected wall from A
without moving unrelated corners. Connected walls share the updated endpoint.
Exact entry does not add a length lock. Existing conflicting constraints reject
the edit atomically. Corner dragging remains free reshaping.

More wall options keeps the existing advanced controls out of the normal workflow.
Resize options and Drag length retain fixed-A, fixed-B and centered edits for
users who explicitly need them. A/B markers identify endpoints in those modes.
Changing length preserves direction, including diagonal walls.

In Drag length mode, dragging an endpoint fixes the opposite endpoint without
another question. Ordinary corner dragging remains free reshaping. Shared corner
IDs update adjoining walls in both rooms. Unrelated corners remain unchanged.
Existing locks and relationship constraints still apply: an incompatible edit
is rejected atomically with its conflict message, not silently solved by moving
unrelated walls. Cancel restores the starting geometry; a completed drag is one
Undo/Redo operation. Advanced numeric entry can explicitly replace the selected length
lock, while hand resizing requires unlocking first. Normal rectangular resizing
honors existing locks; it never silently removes them.

Dots are always enabled, with no on/off control. Dots are directly
on wall centerlines, every 2 ft (609.6 mm) from endpoint A. Every 4 ft
(1219.2 mm), including 8, 12, 16 ft, uses the same slightly larger dot. There are
no numeric marker labels. Changing measurement units does not change the
physical spacing. Dots remain accurate through pan, zoom,
movement and resizing. Dot radii shrink automatically as screen spacing reduces,
keeping neighboring markers separate and major dots larger. Positions are never
resampled or rounded to screen pixels. At extreme zoom-out, dots become subpixel
and cannot remain individually readable; zoom in to inspect them.

Dots are display geometry, not corners, snap targets or wall edits.
They remain independent of the dimension-label toggle and visible during
navigation. Old documents also show dots, even if a former marker setting was off.
Dots do not create history entries or mark a plan dirty.

Automated coverage: fixed A/B and centered increase/decrease in horizontal,
vertical and diagonal directions; shared-room connectivity; unrelated corners;
constraint rejection; Undo/Redo; exact-entry option; endpoint dragging; drag
cancellation; exact dot spacing and sizing; zoom/pan projection and viewport
culling; no text painting; legacy-settings compatibility; absence of a marker-off
control and unchanged geometry/history. Existing navigation,
annotation, snapping and document tests are also run.

Physical Android/iOS touch and visual contrast have not been verified on a device.
The constraint engine rejects conflicts rather than performing a general-purpose
architectural constraint solve.

Simple-room resize regression coverage includes rotated rectangles, repeated
12 ft to 11 ft edits, shared-wall dragging, irregular endpoint edits, locked
conflict rollback, unrelated geometry, tapping dimensions, live adjacent lengths,
and exact Undo. These are automated tests, not physical-phone checks.
