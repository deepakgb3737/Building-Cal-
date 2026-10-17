# EasyFloor preset dimensions

Presets reuse `ShapeSpec.points` for the dimension diagram, placement preview and
committed wall network. Real dimensions remain in millimetres; display/input uses
the board's selected unit (mm, cm, m, ft, in or feet-and-inches).
Prefilled measurement inputs show at most two decimal places without padding
zeros. Applying an unchanged field retains its original full-precision dimension;
wall-dimension unit changes retain precision too. Manually entered values retain
their entered precision rather than silently rounding the underlying geometry.

## Workflow

Choose a preset, enter dimensions, inspect the live labelled diagram, select
**Preview**, and then **Place shape**. **Dimensions / rotation** reopens the
current draft without resetting its values. No walls are committed until placement.
The diagram stays visible while fields scroll when space permits. Focusing a field highlights its
lettered dimension arrow. Short edges use a
letter key instead of squeezing numeric text into an unreadable space; the same
letters identify the fully named fields. Invalid inputs hide the diagram and its
calculated dimensions, explain the conflict, and cannot proceed to placement.
L-shape arm conflicts are shown beside the affected field and refresh when an
overall dimension changes.

The responsive panel uses Flutter's dialog keyboard insets and actual layout
constraints, not a manually subtracted fixed screen height. Field labels wrap
above the inputs and retain the unit. Related inputs use two columns when the
available form width and text scale allow it. Simple presets use smaller panels.
The primary action remains outside the scrolling form. At larger text sizes or
very narrow widths, Cancel becomes a close icon with a Cancel tooltip. Short views
put the diagram inside the scrolling form instead of reserving preview space;
it remains accessible without displacing the active label and input. The
feet-and-inches example appears once, above the fields. Preview labels respect
text scaling, stay inside the diagram and use nearby non-overlapping positions
with connector lines when displaced.

Controllers, focus nodes and keyed fields survive portrait/landscape changes.
Focus scrolling is recalculated as the dialog's available size changes, including
keyboard inset animations. Next advances through dimensions to rotation; Done
validates and returns the preview. Successful submission dismisses the keyboard,
and repeated submissions cannot pop a second route. Existing number fields outside
this workflow keep their previous defaults.

| Preset | Inputs | Calculated / fixed |
| --- | --- | --- |
| Square | Side | Same length on both axes |
| Rectangle | Overall length, overall width | Four right-angle corners |
| L | Overall length/width, vertical arm width, horizontal arm depth | Inner cutout length/width |
| U | Overall length/width, left/right arm widths, base depth | Opening width/depth |
| T | Overall length/width, top bar depth, stem width | Centred stem; stem height |
| Triangle | Base, perpendicular height | Right triangle; sloping side |

Freeform polygon drawing and the existing freehand sketch tool are unchanged.
Rotation remains available. The dimension-entry diagram now uses the same
transformed geometry and dimension spans as canvas placement, including rotation.

L-shapes offer four mirrored orientations, named for the corner where the arms
meet: Top left, Top right, Bottom right and Bottom left. A always measures overall
length, B overall width, C the vertical arm width within A, and D the horizontal
arm depth within B. Mirroring does not swap dimensions. Both arm thicknesses and
their remaining cutout spans must be at least 10 mm. Resizing retains orientation
and scales each arm along its corresponding local axis, including rotated shapes.
Measurement values retain their exact local spans through rigid transformations;
this avoids falsely rejecting a valid 10 mm arm due to rotation rounding.

Confirmed intended decimal-feet case: A=20.58, B=21.39, C=9.88, D=10.70.
These dimensions are valid and are preserved through entry, preview, reopening
and placement in all four orientations. The earlier interpretation reversing A
and C was incorrect; the application does not auto-swap input values.

Controller values and geometry use ShapeDimension identities. Form and preview
letters now use the same ShapeMeasurement.letter mapping rather than separately
assigning letters by list index. A is always width/overall length, B height/overall
width, C verticalArm and D horizontalArm. This removes order-dependent lettering
without changing entered values or weakening geometric validation. The reported
form/preview inversion was not reproduced in the current checkout; no screenshot
was available to establish the original runtime cause.

All dimensions must be finite and within the existing engine limits. Arms must
leave a positive opening/cutout, and each generated wall must be at least 10 mm.
Dragging a pending preset's resize handle scales custom internal dimensions with
the relevant axis instead of resetting them to the old default proportions.
After placement, normal connected-wall editing and undo/redo apply.

## Validation

`preset_dimensions_test.dart`: exact vertices, nonredundant measurement spans,
custom arm proportions, placement connectivity, rigid translation, proportional
resizing, rotation and invalid configurations.

`preset_dialog_test.dart`: all six presets across all six units on a 320 px wide
canvas, focus highlighting, live preview, conflicting inputs, reopening a draft,
and connected placement with the expected individual wall lengths.

`l_shape_orientation_test.dart`: all four mirrored outlines, A/B/C/D spans,
rotation, local-axis resizing, valid/invalid arm dimensions, changes to an overall
dimension, immediate orientation updates, visible field errors, clearing stale
previews and invalid reversed overall/arm inputs. Sixteen automated tests.

`l_shape_mapping_test.dart`: semantic letters are independent of measurement
ordering; the exact confirmed dimensions above are accepted in all four mirrored
orientations. Tests verify every controller, form label, preview span, reopening,
generated vertex, overall dimension and individual wall length.

`preset_keyboard_test.dart`: portrait/landscape rotation with keyboard insets,
retained values and focus, full labels and inputs inside the visible scroll area,
160% text, two-column layout, Next/Done, feet-and-inches entry, visible actions,
and duplicate submission protection. These are simulated keyboard/layout tests,
not physical Android or iOS keyboard validation.

`shape_details_visibility_test.dart`: all six presets with mm and feet/inches,
160% text, viewport widths from 240 to 1024 px, portrait/landscape and simulated
keyboard insets. Checks full focused labels/inputs, reachable actions, retained
values, preview access and non-overlapping diagram labels up to 200% text.

Physical-device checks are not part of this update. Extremely narrow openings or
very large aspect ratios remain physically accurate but may be tiny in a fitted
preview; letter keys and the fully named dimension fields remain available.
