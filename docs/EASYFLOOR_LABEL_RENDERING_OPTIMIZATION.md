# Dense measurement rendering optimization

Date: 2026-10-17.

## Change

Dense plans repeatedly tested label rectangles already rejected earlier in the
same paint. The painter now caches only rejected positions, keyed by rectangle
and wall-clearance policy. Obstacles only accumulate while a frame is painted,
so a rejected position cannot become free within that frame. The cache clears
before every paint; moving walls or removing a panel never retains stale results.
Accepted positions are not cached because later labels occupy more space.

No dependency, geometry rule, measurement value, placement order, UI setting or
stored document changed. Existing collision tests and nearest-position choices
are preserved. A library is not needed for this small renderer optimization.

## Reproducible desktop debug benchmark

Command: `flutter test test/features/easy_floor/measurement_priority_test.dart --plain-name 'Dense overview'`.

Fixture: 220 connected wall segments in a 320 x 400 viewport, all-label overview,
active wall first. One warm-up paint, median of seven subsequent paints. Timing
is diagnostic output, not a flaky hardcoded test deadline.

| Variant | Initial median | Isolated confirmation | Correctness |
| --- | --- | --- | --- |
| Existing collision checks | 29,704 us | 30,319 us | 18 visible labels |
| Per-paint rejected-position cache | 24,161 us | 23,982 us | Same 18 labels, exact same bounds |

The confirmation pair is about 21% lower paint time. A contended repeat while
the full suite and Chrome were running measured 32,888 us; it was not used to
claim a speedup. Both baseline and optimized confirmation ran without that work.
This does not establish mobile frame rate or guarantee a 16.7 ms frame budget.

## Regression checks

- Existing label priority, collision, precision and interaction tests pass.
- The dense test now verifies identical bounds across eight consecutive paints.
- New regression: a full-canvas overlay initially blocks all labels; removing it
  and repainting the same painter restores measurements for both walls.
- Captured before/after placement signatures were identical, including label IDs,
  positions and dimensions.
- All 753 Flutter tests passed. Analysis: no errors/warnings, 62 existing info
  notices. Changed Dart files formatted; Chrome hot reload succeeded (203 ms).

The initial device repeat was blocked by Android installation approval. After
the user approved installation, the current renderer was exercised by five
passing rough-stroke Redmi workflows, including measurement display and editing.
See [Rough-stroke repair](EASYFLOOR_ROUGH_STROKE_REPAIR.md) for the additional
geometry defect discovered and fixed during that repeat. This is functional
device verification, not a phone rendering benchmark. Physical finger comfort
and release-mode performance on dense mobile plans remain unverified.
