# EasyFloor workspace: five-pass review

Date: 2026-10-17. Scope: existing drawing board, touch editing and viewport only.
No toolbar rebuild, additional tools, dependencies or unrelated product features.

## 1. Foundation audit

Read project rules, gesture/pointer lifecycle, shared hit testing, camera fitting,
wall topology, precision assistance, preset geometry/forms, toolbar layout and
existing tests. The starting full suite passed **726 tests**.

Reproduced two defects with new widget tests before production repairs:

- A locked standalone wall could rotate through an endpoint drag when its length
  remained constant. Length validation alone cannot reject that interaction.
- Fit to Screen fitted tall geometry behind the floating toolbar, both in its
  default bottom position and after dragging it to the top. A compact rectangle
  did not expose the defect, so reproduction uses a tall plan.

The Android integration test also still referenced the removed `Single wall`
label. Updated it to the existing `Wall` control.

## 2. Touch and gesture pass

Direct corner editing now rejects a corner attached to a length-locked wall,
with a clear instruction to unlock the connected wall first. The whole edit is
reverted through the existing conflict/preview path; no geometry or history
operation is committed. This closes the same-length rotation loophole without
introducing a new lock type or changing persisted constraints.

The lock/camera/navigation focused run passed **16 tests**. Existing tests cover
unlocking, direct locked-wall rejection, shared-corner conflicts, Undo/Redo,
pinch interruption, text resizing and cancellation.

## 3. Geometry and precision pass

Ran the existing underlying-engine and widget scenarios rather than replacing
working geometry. **117 tests passed** across accidental drawing, navigation
switching, full-direction wall movement, endpoint connections, midpoint joins,
right-angle assistance, open and deliberately closed C/U outlines, L mapping,
line alignment and repeated-edit canonical geometry checks.

The seeded integrity tests execute 100 mixed edits per seed (17, 42, 2026),
checking atomic rejection, unaffected independent geometry, validated model
round trips and complete Undo/Redo snapshots. No additional geometry defect was
reproduced in this pass; no speculative rewrite was made.

## 4. Responsive workspace pass

Fit to Screen now uses the existing camera engine to compare unobstructed
regions around the current floating toolbar and persistent Text controls. It
chooses the fit with the largest usable scale, preserving aspect ratio and
real-world geometry. Hide UI omits the hidden toolbar obstacle. Fitting also
clears stale whole-room selection alongside the existing wall/corner selection
clearing, so a room inspector does not remain after fitting.

The toolbar itself and its visibility/position state were not rebuilt. Ordinary
edits still preserve the viewport; fitting is an explicit navigation action.

New fit regressions check the entire wall path, not just its endpoints, against
the toolbar at 320x740, 740x360 and 240x420, with toolbar at the top and bottom.
The combined responsive run passed **52 tests**, including all six shape panels,
keyboard-inset simulations, rotation, readable labels, toolbar-state retention
and the exact intended L measurements in all mirrored orientations.

## 5. Final reinspection and QA

Reinspected the changes against existing navigation, selection, geometry and
locking boundaries. The final complete suite passed **733 tests**, including
seven new regressions in `test/features/easy_floor/workspace_upgrade_test.dart`.
The focused counts above overlap the full suite; they are not extra unique tests.

`flutter analyze` reports **no errors or warnings** and **62 existing info-level
notices**. Its default exit status remains nonzero because info notices are fatal
by default. Formatting checked for the changed Dart files.

Android integration build succeeded in 27.5 seconds and installation in 8.6
seconds on Redmi Note 8, Android 11 (API 30). Output:
`build/app/outputs/flutter-apk/app-debug.apk`. Existing Java source/target 8
deprecation warnings remain. Chrome startup and hot reload passed (147 ms).

### Physical-device status

The Redmi was connected and installation succeeded, but Android reported an
active lock screen (`showing=true`). Waking the display did not unlock it.
The initial interaction run stalled at its first rectangle scenario and was
stopped after requesting that the user unlock the phone.

After the user unlocked it, reran
`flutter test integration_test/easy_floor_wall_sides_test.dart -d d7a8dc04`:
**all three scenarios passed** (rectangle, diagonal, partition) in 63 seconds of
test execution. The retry debug build/install also passed (14.7 s / 9.8 s).
The run exercised seven walls, each at three positions along its length, from
three sides/offsets, in two normal directions: **126 drag/cancel checks**, plus
seven committed moves followed by Undo. Assertions check the selected wall,
live measurements, preserved wall length, requested displacement, unrelated
corners and exact cancellation/history restoration.

These are injected Flutter integration gestures running on a physical Redmi,
not manual human finger/stylus testing. The test app was visibly running on the
unlocked phone. No iOS interaction tests were run.

### Debug timing samples

Existing desktop debug benchmark, median of five samples, not mobile frame rates:

| Walls | Snap | Corner preview | Finalization | Paint | Whole-room move |
| --- | --- | --- | --- | --- | --- |
| 60 | 0.080 ms | 0.334 ms | 0.529 ms | 3.763 ms | 0.450 ms |
| 220 | 0.044 ms | 1.887 ms | 1.685 ms | 7.704 ms | 1.669 ms |
| 840 | 0.142 ms | 1.389 ms | 3.745 ms | 10.488 ms | 2.221 ms |

These timings were collected while other verification processes were running;
they are approximate diagnostics, not performance acceptance guarantees.

## Scenario matrix

| Scenario | Automated result | Physical-device result |
| --- | --- | --- |
| Intentional strokes, taps/jitter, 360-degree wall moves | Pass | Rectangle/diagonal/partition wall-side moves pass; full gesture set not verified |
| Endpoint joins, T/cross junctions, shared corners | Pass | Not verified |
| Rectangles, L/C/U and irregular/open layouts | Pass | Not verified |
| Connected movement, exact sizes, dimensions and units | Pass | Rectangle/partition movement and live lengths pass; exact input/unit changes not verified |
| Red lock state, unlocking, direct locked-corner rotation rejection | Pass | Not verified |
| Second-finger interruption, pan/zoom and cancellation | Pass | Not verified |
| Shape panels, simulated keyboard, rotation and small screens | Pass | Not verified |
| Fit around movable toolbar and geometry preservation | Pass | Not verified |
| Undo/Redo, deletion and repeated complex edits | Pass | Cancellation and Undo after wall moves pass; other operations not verified |

## Remaining boundaries

- Locks remain the existing measured-length constraints, not absolute-position
  pins for every explicit group operation. Whole-group rigid movement preserves
  internal lengths; the direct corner/wall guards do not redefine that model.
- Manual finger targeting, Android/iOS IME behavior, human usability and mobile
  frame pacing still require further device validation. Widget/injected tests
  cannot establish that the workspace feels natural to every first-time user.
- Wall-tool endpoint continuation retains the existing policy: drag an unselected
  open endpoint to continue; tap it first to select it for reshaping. Draw keeps
  direct corner dragging. This remains an inherently ambiguous touch interaction.
- Fit avoids the floating palette and persistent Text panel, not every transient
  dialog or notification. Modal forms still cover the canvas while being edited.
- Very dense labels and extreme aspect-ratio presets still depend on contextual
  hiding and letter-key diagram labels; no universal no-clutter guarantee is made.
