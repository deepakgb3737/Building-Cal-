# Tape Measure

Select **Tape** in the existing floating toolbar, then drag from one point to
another. The temporary line, endpoint markers and distance update live and remain
after release. Drag either marker to adjust that end. Drag away from both markers
to begin another measurement. **Clear** removes the current tape without leaving
the tool; tap Tape again to return to normal drawing.

**Snap** is enabled initially and can be turned off for arbitrary canvas points.
It prioritizes corners within 12 logical pixels, then the nearest wall edge.
The board converts this screen-space tolerance to world units at the current
zoom. A displaced snap uses the existing target indicator. Measuring never calls
wall insertion, connection or movement methods.

## Accuracy and display

Endpoints use the existing world-coordinate model in millimetres. Distance uses
the Euclidean length of their difference, including diagonal measurements.
Display uses the board's selected unit and standard formatter (mm, cm, metres,
feet, inches, or feet-and-inches). The exact underlying distance is retained;
formatting precision does not round or alter the model. Measurements are only
as physically accurate as the plan scale and dimensions; this is not a camera,
laser or real-world sensor measurement. Calibrate the plan using a known wall
dimension before relying on a freehand sketch for site distances.

The tape label is active-priority and uses existing collision-aware placement,
panel/toolbar obstacles and a subtle background. Ordinary wall measurements and
angles yield to the tape overlay. Text annotations remain separate; measuring
cannot select/edit them. Temporary tape labels are not wall-label hit targets.

## Navigation and recovery

Two fingers retain the existing pan/pinch navigation. Introducing a second
finger during measurement restores the prior tape before navigating. Cancelling
a drag restores its previous endpoints. Navigation changes only the camera,
not measured world positions. Switching tools removes the temporary tape.

Tape interactions never commit to wall/annotation undo history, change geometry,
lock walls or become saved document geometry. Existing Undo/Redo still operate
on actual drawing actions. No persistent settings, dependencies or new drawing
engine were introduced.

## Regression coverage

`test/features/easy_floor/tape_measure_test.dart` covers horizontal, vertical and
3-4-5 diagonal lengths; live and released state; corner/edge snapping and Snap
off; Clear; endpoint adjustment; gesture cancellation; a second-finger
interruption; zoom; all display units; rotation; switching tools mid-drag;
toolbar collision avoidance; unchanged geometry and unchanged drawing history.

Tests exposed an existing narrow app-bar overflow with the feet-and-inches unit.
The unit button now has a stable 48 x 48 touch target and compact unit text.
The toolbar also measures the actual secondary tool count inside its padding,
so Tape's two contextual controls do not reserve space for six controls.

Verification: all **779 Flutter tests passed**, including 14 tape regressions.
The focused tape suite was repeated after the final snap-indicator adjustment
and passed. Analysis reported no errors/warnings and 62 pre-existing info notices
(default nonzero exit). Changed Dart files were formatted; Chrome hot reload
succeeded. Android device inventory was empty at final verification.

Physical-phone touch comfort, actual keyboards and release-mode performance are
not established by widget tests. No Android device was connected during initial
implementation; do not treat prior Redmi drawing tests as tape-tool validation.
