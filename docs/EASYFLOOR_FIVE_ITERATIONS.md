# EasyFloor Five-Iteration Quality Log

Scope: existing 2D board, geometry, gestures, dimensions, presets and workspace.
No unrelated tools or dependencies. Baseline: 676 tests passed.

## 1. Foundation Audit

Inspected wall topology/validation, transactions, snapping/hit testing, history,
camera transforms, painter labels, preset forms and palette state. Found:
near-end wall projections could outrank a valid corner snap, creating a proposed
sub-10-mm split that the engine then rejected. Regression tests reproduced both
the failed connection and invalid projection offer. Shared `WallNetwork.snap`
now excludes such projections; endpoint selection and valid interior junctions
remain available. Verification results are recorded after each completed pass.
Iteration 1 result: 34/34 targeted tests passed (2 new regressions).

## 2. Gestures And Connected Geometry

Independently reviewed pointer lifecycle, threshold/commit gates, 360-degree
translation, snap fallback, shared vertices, multi-touch and history. Added a
three-finger interruption/cancellation journey followed by intentional joining
and exact Undo/Redo. Ran it with accidental-touch, free-movement, pinch and
recovery suites: 42/42 passed. No additional production change was justified;
the new regression protects the mixed workflow rather than duplicating tools.

## 3. Dimensions, Presets And Precision

Reproduced a rapid-focus race: coalesced reveal requests could be dropped, stale
targets could run later, and queued post-frame work lacked a scheduled frame.
Reveal work now resolves current focus, replays newer requests and schedules its
frames. Also reproduced clipped full labels with only 106 px of keyboard-safe
dialog height. Such forms now use one scroll owner, one column and reachable
scrolling actions; normal forms retain pinned actions. Above-label inputs leave
whole-field reveal to their enclosing form instead of adding caret-only padding.
Seven new regressions plus keyboard, visibility, precision and smart-label suites:
73/73 passed. Intermediate failing runs were repaired, not removed.

## 4. Workspace And Visual Review

Reproduced measurement labels being painted underneath the movable palette.
The painter now receives its current bounds as a label obstacle only while UI is
visible. Moving/collapsing the palette or hiding UI updates the available space
without changing geometry. Workspace/palette/toolbar/label/distraction-free
checks: 30/30 passed, including the new overlay regression.

Inspected three real-font Flutter captures, retained in `build/quality-review/`:
`connected-plan.png`, `preset-portrait.png`, `preset-short-landscape.png`.
These are rendered widget previews, not phone screenshots. The compact keyboard
case scrolls actions because 106 px cannot hold a complete form and pinned
footer simultaneously. A temporary capture-harness asynchronous-I/O stall was
corrected. Its preset-label tap warning was traced to tapping a text render box
inside a chip; the shared test helper now targets the actual shape button.
The captures were regenerated without tap warnings. The machine-specific
temporary capture test was removed; screenshots remain review artifacts only.

## 5. Independent Final Audit

Read the final engine and interaction code, then added three deterministic
100-operation scenarios mixing translation, corner moves, exact resizing and
locking/unlocking on connected rooms plus an independent wall. Every completed
operation remained canonical/reloadable; rejected edits were atomic; unrelated
wall coordinates and Undo/Redo snapshots remained exact. No additional geometry
change was justified by these checks. Together with complete small/large/rotated
mobile-sized workflows and the timing audit: 8/8 targeted tests passed.

Desktop debug samples (not phone frame-rate claims): 60/220/840-wall plans had
median paint times of 2.18/3.60/6.39 ms, respectively. The 840-wall sample had
0.83 ms preview edits and 2.72 ms junction finalization.

## Defect Summary

| Problem | Root cause | Repair | Regression |
| --- | --- | --- | --- |
| Near-corner connections rejected | Projection proposed a sub-minimum split | Exclude unusable projections in the shared snap engine | `quality_foundation_test.dart` |
| Latest focused dimension hidden | Coalesced requests dropped; stale target and unscheduled post-frame work | Resolve current focus, replay requests and schedule frames | `quality_dimension_entry_test.dart` |
| Labels clipped in short keyboard views | Pinned footer and wrapped two-column labels consumed available height | Single-column scroll owner with reachable actions; whole-field reveal owns padding | `quality_dimension_entry_test.dart` |
| Measurements hidden under floating tools | Palette omitted from label obstacles | Include current visible palette bounds, release them in Hide UI | `quality_workspace_test.dart` |

## Final Verification

- Full `flutter test`: **690 passed**, exit 0; baseline was 676. Targeted counts
  above overlap; they are not additional independent totals.
- `flutter analyze`: **0 errors, 0 warnings, 62 pre-existing informational
  notices**, exit 1 because the default command treats info notices as fatal.
  This is not a clean analyzer exit; no new notices were left by this update.
- Affected source and test formatting check: no changes required.
- `flutter build apk --debug --no-pub`: succeeded, exit 0. Output:
  `build/app/outputs/flutter-apk/app-debug.apk` (approximately 155 MB).
- Existing build warnings remain for Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20 and
  Java 8 source/target support. Toolchain upgrades were not mixed into UI repairs.
- Final Chrome debug startup and hot reload succeeded (129 ms reload). The
  headless browser used CPU rendering, not a physical phone GPU.
- Final full-suite logs contain no failed tests, framework exceptions or missed
  tap warnings. Temporary screenshot code was removed after visual review.

## Assessment And Limits

The audited workflows are more predictable: corner connections no longer offer
unusable cuts, fast focus changes retain visible fields, constrained forms remain
reachable, and dimensions avoid floating tools. Geometry integrity, automatic
interaction, full-direction movement and reversible editing passed the targeted
and full regression suites. No unrelated features or dependencies were added.

This is evidence for the tested workflows, not a guarantee for every geometry,
phone or input method. Flutter detected macOS and Chrome only; no physical Android
or iOS device was available. Phone touch feel, the 8-logical-pixel threshold,
real OS keyboards, accessibility services and phone frame rates remain unverified.
Screenshot keyboard space used simulated insets. Very short views require
scrolling actions instead of showing fields and buttons simultaneously. Native
macOS/iOS builds, release signing and store readiness were not checked.
