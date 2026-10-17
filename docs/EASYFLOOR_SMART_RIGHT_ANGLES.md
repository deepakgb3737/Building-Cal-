# Smart 90-degree drawing and connected walls

## Root causes and focused changes

- All endpoint drags previously entered corner editing, so drawing successive
  individual walls required a hold. In the existing Wall tool, dragging an
  unselected degree-one endpoint now starts another wall. Tap the endpoint first
  to select it for editing. Shared corners and wall interiors retain hold-to-branch;
  Draw keeps direct corner editing. No additional mode or toolbar was added.
- Default angle assistance previously considered only board axes. It now also
  considers the attached wall direction (including a midpoint connection) and the
  preceding uncommitted stroke segment. Corrections still require both angular
  and zoom-adjusted spatial proximity; arbitrary angles remain available.
- The existing assistance toggle identifies 90-degree assistance / Free Angle.
  Existing shared-corner topology, snap targets, guides, contextual angles,
  geometry validation and history remain authoritative. No C-specific geometry,
  inferred room objects or room fill was introduced.

## Automated verification

New tests: `test/features/easy_floor/smart_right_angle_test.dart`.

| Scenario | Evidence |
| --- | --- |
| Rectangle from separate connected walls | New widget test; four shared vertices |
| L in both drawing directions | New sequential-stroke widget tests |
| Open C in both directions | New widget tests; four segments, five vertices, no enclosure |
| Deliberately close the C endpoints | New widget tests; closure only after the final stroke |
| Open U | New sequential-stroke test; two open endpoints |
| Diagonal and 180-degree continuation | New unit/widget tests; no axis forcing |
| 90-degree snapping / Free Angle | New attached/previous/midpoint reference tests; existing cardinal and line-alignment suites |
| Live right-angle feedback | New widget test checks actual preview angle, contextual 90-degree angle and guides |
| Midwall / endpoint connection | Existing endpoint-connection and free-wall-movement suites; selected endpoint setup updated for the Wall interaction |
| Connected translation, movement away | Existing free-wall-movement suite |
| Near-target rejection | Existing out-of-range snap, endpoint and quality-foundation tests |
| Zoom, pan, dimensions, history | Existing navigation, units, pinch and movement suites; C Undo/Redo checks |
| Second finger interrupts a new branch | New widget test; original geometry restored and preview discarded |
| Duplicates and geometry integrity | Existing junction, reliability and repeated-edit integrity suites |

The focused ten-test suite passes. The complete suite passes all 700 tests after
all changes. Static analysis has no errors or warnings; its 62 existing info-level
findings still cause the default analyzer command to exit nonzero. Headless
Chrome startup and hot reload succeeded (156 ms); this is not physical-phone
validation.

## Remaining validation / interaction boundary

No Android/iOS physical-device checks were performed for this change. Finger
thresholds, stylus behavior and discoverability still need on-device review.
Endpoint creation versus corner editing is inherently ambiguous: the existing
Wall tool favors continuing an unselected open end; tap first to reshape it.
This policy does not replace Draw-mode corner editing or shared-junction editing.
