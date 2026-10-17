# Whole-stroke refinement review

Date: 2026-10-17. The supplied attachment ends at the first item of its
five-stage review; this report records five concrete stages without assuming
missing instructions.

## 1. Capture and geometry audit

Reused the existing raw-stroke capture, adaptive simplifier, residual-point
cleanup, optional shape interpretation, preview and validated wall insertion.
The previous Redmi repair already addressed extra fragments in U and angled
sketches. Keep Original still preserves intentional raw detail; it is not a
promise to commit a perfectly straight line after rejecting refinement.

Existing canonical insertion handles repeated/overlapping segments, shared
corners and intersections. No global collinear-wall merge was added: separate
segments can represent intentional measurements and junctions.

## 2. Complete-chain gap

Previously Straighten existed only during initial sketch review. Added
**Straighten wall chain** to the existing selected-wall More options, not a new
toolbar or drawing mode. It follows connected degree-two, nearly collinear walls
in both directions and stops at branches, genuine corners and protected walls.
The entire proposed chain is checked against its endpoint line and the current
screen-derived tolerance (3 logical pixels converted to mm).

The operation returns a separate candidate network. It preserves the two outer
endpoints, leaves unrelated wall records intact, rejects a new unintended
connection, and uses canonical wall insertion. It does not cross locked spans
or geometric constraints. A lone wall or meaningful bend produces an explanation,
not a silent change. Repeating successful cleanup has no additional eligible
segments to change.

## 3. Contextual line refinement

New two-point stroke proposals can reuse precisionPoint for nearby parallel,
perpendicular and axis directions when existing angle assistance is enabled.
References must be near the anchor; the endpoint correction and every original
sample must stay within the existing adaptive tolerance. Attached endpoints are
authoritative. Alignment does not request endpoint snapping and is rejected if
it newly lands exactly on existing geometry. Both-attached lines and deliberate
free-angle strokes remain unchanged. Existing interactive snapping still owns
intentional connections; this pass does not enlarge its tolerance.

## 4. Preview and recovery

Whole-chain cleanup displays the full candidate plan and highlights the proposed
line in the existing painter. No model/history change occurs until Apply.
Cancel leaves the exact original network. Apply commits once, and Undo restores
all original segment records and connections. The scrollable preview dialog has
Cancel/Apply controls and is tested after landscape/keyboard inset changes.

## 5. Validation scope

All **765 Flutter tests passed**, including nine new whole-stroke regressions.
Static analysis reports no errors/warnings and 62 pre-existing informational
notices (which cause its default nonzero exit). Changed Dart sources were
formatted and the running Chrome app hot reloaded successfully.

New whole_stroke_refinement_test covers connected jitter chains, a C-shaped
layout, branch preservation, separate collinear walls, fixed geometry,
unintended junction prevention, nearby parallel alignment without connection,
attached endpoints, deliberate diagonals, repeated refinement, duplicate strokes,
three zoom tolerances, preview/cancel, exact length and Undo.

Existing suites cover long/dense jitter, L/U/T/irregular and open sketches,
stroke cancellation, original/refined history, T/cross junctions, locked spans,
measurement labels, small screens and navigation interruption. These systems
were reused rather than duplicated.

Limit: chain selection uses connected topology and a conservative direction
threshold, not historical stroke provenance. It stops rather than flattening a
meaningful bend. Multi-corner refinement remains available in initial sketch
review; committed arbitrary branching components are not flattened as a whole.
The Redmi was disconnected when this update was checked, so this update has no
new physical-device validation. Earlier Redmi results do not validate these new
paths. Manual finger comfort and release-mode rendering performance remain
unverified. No dependencies, persistent settings or document schema changed.
