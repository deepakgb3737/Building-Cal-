# Final small-screen usability audit

Date: 2026-10-17. Scope: existing drawing board and exact-dimension interaction.

## Defect reproduced and fixed

An exact length rejected by a locked-wall constraint dismissed the dimension
dialog. The explanation appeared on the canvas after the entered value was
lost. A split longer than its wall had the same recovery problem.

Dimension submission now checks the requested operation on a copy through the
existing geometry engine. A conflict stays in the dialog with its explanation
and entered value intact. The user can correct it or cancel. Valid operations
still use the same engine and commit once to history. Resize, Split and scale
calibration callers share this behavior. Conflict messages are announced through
a semantic live region. No geometry formulas or constraint rules were changed.

This change makes correction easier, prevents repeated re-entry, preserves the
engine's validation, and removes a reopen step. It adds no drawing mode, toolbar
control, dependency or persistent setting.

## Workflow coverage

| User risk / workflow | Automated result |
| --- | --- |
| Tap/jitter accidentally creates a wall | Existing accidental-drawing tests cover touch, stylus, mouse, density and zoom |
| Thin walls/corners or nearby targets select incorrectly | Existing wall-sides, automatic-touch and target-priority tests |
| Snapping breaks endpoints or junctions | Existing endpoint, T/cross-junction and repeated-edit geometry tests |
| Hidden/redundant/overlapping measurements | Existing label priority, collision, redundancy and exact-label-edit tests |
| Pinch interrupts a drag and leaves geometry behind | Existing navigation-switching and pinch-reliability tests |
| Exact entry conflicts with a lock | New portrait/landscape recovery tests preserve input and geometry |
| Invalid Split requires starting again | New test corrects the value in place, then verifies Undo/Redo |
| Small-screen complete drawing workflow | Added 320 x 568 case with essential labels enabled |
| Complex connected editing | Complete journey draws a room, resizes, enters a dimension, adds a partition and independent irregular outline, translates connected geometry, deletes/undoes, pinches and resumes drawing |
| Keyboard, rotation and action accessibility | Existing preset and dimension keyboard/layout suites |

The new conflict tests cover 320 x 568 portrait and 740 x 360 landscape. Rejected
submissions via Apply and keyboard Done preserve the plan; cancellation does not
add history entries. Unlocking, applying a valid length and successive Undo
restore the preceding states. The full journey also runs at 320 x 740 and
430 x 900; compact sketch-review cases cover 240 x 420 and 740 x 360 with
enlarged text.

## Limits

Verification: all **752 Flutter tests passed**. Static analysis reported no
errors or warnings; its 62 existing informational notices retain a nonzero
default exit. Changed Dart files were formatted. The headless Chrome app
launched and hot reloaded successfully (180 ms). All automated scenarios above
passed; physical-device scenarios below are not tested in this pass.

These are automated Flutter gestures and simulated viewport/keyboard states,
not observations of a first-time person using the phone. The connected Android
device reported keyguard showing, asleep and display off; no new physical-device
workflow was run. Manual finger/stylus comfort, real keyboard behavior and
release-mode frame pacing remain unverified. Dense all-label overviews on slower
phones remain a known performance risk, not a solved problem in this patch.
The 220-wall all-label desktop debug sample took 86,809 microseconds with
18 non-overlapping labels visible; this is diagnostic timing, not a release-mode
mobile frame-rate guarantee.
No claim of universal compatibility or defect-free behavior is made.
