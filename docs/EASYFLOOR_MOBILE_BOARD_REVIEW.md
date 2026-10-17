# Mobile drawing board review

Date: 2026-10-17.

## Confirmed defect and repair

At a 740 x 320 logical-pixel viewport, the floating palette divided its limited
height equally between its rows. This left the primary row with a 2.4-pixel
scroll extent even though allocating the available space differently could fit
it completely. Primary controls now receive their measured height while
retaining at least a compact, scrollable secondary row where space permits.
The palette's total size, position, collapse state and existing actions are
unchanged. Extremely small viewports still use scrolling rather than shrinking
touch targets or overflowing the canvas.

Added a regression in `professional_toolbar_test.dart` that fails before the
repair and verifies the primary row, collapse state across rotation, and
unchanged geometry afterward.

## Existing behavior retained and regression coverage

| Concern | Automated coverage |
| --- | --- |
| Narrow screens, large text, portrait/landscape controls | professional_toolbar_test, floating_palette_test |
| Collapsed/hidden state and selection stability | toolbar_state_test, workspace_stability_test |
| Fit around toolbar and preserve geometry | workspace_upgrade_test |
| Wall targeting from both sides, zoom and free movement | wall_sides_test, free_wall_movement_test |
| Default right-angle and free-angle drawing | smart_right_angle_test |
| Active/essential label priority and panel avoidance | measurement_priority_test |
| Preset fields, previews, keyboard and rotation | shape_details_visibility_test, preset_keyboard_test, dimension_keyboard_layout_test |
| Two-finger interruption and camera continuity | navigation_switching_test, pinch_reliability_test |
| Connected edits, dimensions, deletion and undo | natural_complete_journey_test and geometry regression suites |

The touch boundary already converts logical-pixel hit radii to world coordinates
(22 px corners, 16 px walls, 6 px endpoint core). Navigation already rolls back
interrupted edits, and Fit excludes tool bounds. These systems were not replaced.
No formulas, stored documents, geometry rules, toolbar actions or dependencies
were changed in this pass.

## Verification limits

`flutter test`: all 748 tests passed. The focused palette/state/fit run passed
20 tests. `flutter analyze`: no errors or warnings, but 62 existing informational
notices cause its default nonzero exit. Changed Dart files were formatted.

Widget tests simulate screen dimensions, text scale and keyboard insets; they do
not establish physical keyboard, finger/stylus accuracy or performance on every
phone. No new physical-device test was performed in this pass. The headless
Chrome app launched and hot reloaded successfully, but CPU-only rendering is
not a mobile GPU performance test. Dense all-label overview rendering remains
a performance risk on slower devices; this small layout repair does not claim
to resolve it.
