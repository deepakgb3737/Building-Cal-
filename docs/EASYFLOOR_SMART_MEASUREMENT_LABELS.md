# Smart measurement labels: five-pass review

Date: 2026-10-17. Changes are limited to label rendering, label interaction and
the new-plan visibility default. Wall geometry, units, connections and formulas
remain unchanged. No dependencies or new drawing controls were added.

## 1. Audit and baseline

The initial full Flutter suite passed **733 tests**. Inspected the painter,
geometry-based redundancy groups, pointer targeting, exact dimension dialogs,
saved settings, presets and label collision tests.

Identified these gaps:

- Only selectedWall received first placement priority. Other affected walls in
  contextWalls, or attached to an active corner, could be placed after overview
  walls and lose useful space.
- Live preview labels had no whole-canvas fallback because the fallback required
  a committed wall ID.
- Label obstacles included notes and the toolbar, but not contextual inspectors.
- Dimension-label drags translated the associated wall, making slips destructive.
- New plans hid every idle measurement instead of explaining the drawing with
  essential dimensions.

## 2. Priority and live measurement pass

The painter now uses Active, Essential and Secondary priorities. Selected,
affected and corner-connected wall labels are placed first; overview segment
labels follow; optional angle/offset information is placed last. All active
wall measurements use the active appearance, not just the selected wall.

Existing isolated-rectangle redundancy groups still identify genuinely duplicate
dimensions. These duplicates are secondary and remain hidden unless selected or
otherwise relevant; equal lengths in unrelated walls, partitions, shared walls
or irregular layouts are not treated as duplicates.

New plans enable essential overview labels. Explicit saved false/true settings
are honored; the existing Labels control can still hide the overview. Active
drawing/editing remains contextual. This changes the default, not stored files.

Live drawing labels can search clear canvas space when local candidates fail,
with a leader back to the corresponding segment. Preview bounds reset on every
paint so ended/cancelled previews do not retain stale hit regions.

The existing contextual/redundancy/every-segment focused run passed **24 tests**
before the later touch-zone refinement. Final coverage includes those suites.

## 3. Collision, redundancy and zoom pass

Read contextual inspector bounds at paint time, after Flutter has laid them out,
and in the board's coordinate system. Ignore detached render objects during
inspector removal. This avoids a stale first-frame bounds snapshot and does not
add a rebuild listener or parallel layout system.

Both active and essential measurements may use wider fallback placement;
secondary information cannot displace them. Secondary corner details disappear
when an adjacent wall projects below 48 logical pixels. Offset/parallel secondary
labels are suppressed for segments below 72 pixels. These are display rules only;
real measurements and exact inputs are unchanged.

The collision/junction/zoom focused run passed **61 tests** before adding the dense
overview case. Tests compare actual rendering with and without corner details at
two zoom levels while requiring both affected wall measurements to remain.

## 4. Units, shapes and interaction pass

Passed **52 focused tests** covering presets, all L orientations, exact dimension
mapping, keyboard/rotation simulations, visibility, locked-wall rendering and
toolbar interaction. All six supported display units are covered by new live
diagonal-length checks.

Dragging a label now selects its associated wall but never moves it or creates a
stroke. Tapping still opens its exact dimension editor. Updated the old test
that explicitly expected label dragging to translate a wall.

The full review exposed a related conflict: close labels could overlap the wall's
invisible drag zone. Labels now leave that zone clear (18 px edge clearance for
axis-aligned walls, direction-adjusted for diagonal rectangular bounds), and
enlarged label hit regions defer to wall touches within 16 px. Direct label taps
retain priority. Nearby-placement tests now assert the touch-safe minimum rather
than the former 6 px clearance. Whole-wall, two-sided drag tests remain intact.

A drawing fixture was also updated to start its new diagonal on genuinely empty
canvas rather than on a measurement label, which must now select rather than draw.

## 5. Final reinspection, regression and performance

New regressions in `measurement_priority_test.dart` cover active-first ordering,
affected corners, crowded live fallback, inspector bounds and hide/show,
non-destructive label dragging, diagonal live values in every unit, adaptive
secondary rendering and a dense short-segment overview. Existing suites verify
rectangles/squares, L/C/U and irregular layouts, partitions, T/cross junctions,
short/parallel/diagonal walls, units, locks, deletion, exact edits and Undo/Redo.

The dense overview has 220 wall segments. It rendered 18 non-overlapping labels,
kept the active wall first, and suppressed labels with no clear placement. A
bounding-box broad phase skips unnecessary exact wall intersection checks.
One desktop debug sample took about **83 ms** (not a mobile frame-rate guarantee).
This remains a dense-overview performance risk; ordinary active-edit benchmarks
with only contextual labels are not equivalent to this case.

Final verification:

- **747 tests passed**, including 14 new priority/layout regressions. Focused
  counts above overlap this full suite.
- `flutter analyze`: no errors or warnings, 62 existing info notices. Default
  analyzer exit remains nonzero because of those notices.
- Final Android debug APK built successfully in 11.8 s at
  `build/app/outputs/flutter-apk/app-debug.apk`; existing Gradle/AGP/Kotlin future
  support notices remain.
- Chrome startup and final hot reload passed (614 ms).
- All 11 changed Dart files passed the format check with no pending changes.

## Remaining boundaries

- There is no mathematically possible placement of every measurement on every
  dense phone-sized plan. Unplaceable labels are omitted rather than overlapped;
  selecting a wall gives it first priority, and zooming exposes more clear space.
- Genuine rectangle/square duplicates remain suppressed even when zoomed in.
  Secondary angle/offset details restore when their zoom/space tests permit.
- If the entire usable canvas is covered or a wall is entirely offscreen, its
  label may have no valid placement. No overlay covers controls to fake visibility.
- The phone was connected but locked during this update. Previous Android wall
  movement results do not verify this new label code. No new physical-device label,
  manual finger/stylus, Android/iOS keyboard or mobile frame-pacing checks are claimed.
- Current application styling is light-theme based. This update does not enable
  a full dark theme or change the centralized style boundary.
