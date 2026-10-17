# BuildCalc Development Rules

Read this file and `README.md` before editing. These are development instructions, not automated lint enforcement.

## Shared UI Source

| File | Responsibility |
| --- | --- |
| `lib/ui/app_colors.dart` | Interface and drawing colors |
| `lib/ui/app_typography.dart` | Font family and reusable text styles |
| `lib/ui/app_styles.dart` | Corner radii and reusable button styles |
| `lib/core/theme/app_theme.dart` | Material theme and default component styling |
| `lib/ui/app_widgets.dart` | Shared converter and numeric input widgets |

## Styling Rules

- Use `AppColors`. Do not add `Color(...)`, hexadecimal colors, or `Colors.*` directly to screens or painters. Define genuinely new colors centrally with descriptive names.
- Use `AppTypography` for fonts and base text styles. Do not add screen-local `TextStyle` constructors or font-family strings.
- Use `AppRadii` rather than screen-local radius definitions.
- Prefer `AppTheme` component defaults. Use existing `AppButtonStyles` variants for distinct visual roles; define new reusable variants centrally, not in screen-local `styleFrom` calls.
- Reuse `AppConversionField` and `AppNumberField` when their behavior fits. Preserve controllers, formatting, validators, focus behavior, and error messages.
- Extract repeated UI with identical behavior and appearance into shared widgets. Do not create wrappers for every one-off widget.
- Keep the UI simple, white, readable, and mobile-friendly. Do not add decorative cards or fonts without a design requirement.

## Local Layout Boundary

Padding, spacing, constraints, breakpoints, scrolling, and feature-specific drawing geometry may remain in screens and painters.

Responsive text sizing may use `AppTypography.<style>.copyWith(fontSize: calculatedSize)`. Runtime colors must originate from shared definitions. Drawing stroke widths and label positions may remain local because they depend on scale and geometry.

Existing screens still contain local shadows, opacity values, elevation, and responsive size/weight overrides. Styling is not fully centralized today. When introducing or changing a reusable visual effect, define it in `lib/ui/` and update affected callers. Avoid unrelated redesign and do not claim zero local styling.

## Calculation Separation

- EasyFloor's active geometry is in `lib/features/easy_floor/logic/`. Keep it
  independent of Flutter widgets, canvas objects and pixel coordinates. Store
  real dimensions in mm, share corner IDs between connected walls, and validate
  changes atomically. Drawing UI must not independently modify wall lengths.
  Smart-touch selection must share `WallNetwork.hitTest` across tap, drag and
  resize initiation. Convert touch tolerances to world units at the UI boundary;
  do not let overlapping endpoint hit areas turn a midpoint wall drag into a
  corner resize. Explicit corner tools and multi-selection retain their rules.
- EasyFloor annotations live separately in `logic/drawing_annotations.dart`.
  Never insert text into wall snapping, topology, constraints or measurements.
  Text changes must commit their layer through `DrawingHistory`; wall-only commits
  retain the existing annotation snapshot. Restore both layers after Undo/Redo.
- Sketch refinement history may also hold a temporary `SketchRefinement`
  snapshot. Restore it as a preview, never as unvalidated wall geometry. Clear
  drafts on document reset; persistent documents must contain canonical geometry
  only. Undo/Redo controls must remain accessible while reviewing a restored draft.
- Use `logic/drawing_camera.dart` for camera scale limits and fit calculations.
  Navigation must never commit geometry/history edits. Fit annotation bounds
  using the same text layout as the painter, not cached screen rectangles.
  Pinch gestures must roll back interrupted edits and stay navigation-only until
  all fingers lift. Keep annotation resizing separate from wall geometry.
- EasyFloor documents use `logic/floor_document.dart` and the validated
  `DocumentRepository`; native/browser storage adapters implement
  `DocumentStorage`. Keep JSON parsing and filesystem/browser I/O out of widgets.
  Validate before writing or applying loaded data. Mark saved only after a write
  succeeds; failed saves and cancelled switches must preserve the current plan.
  Reset paired history on document replacement. Never silently overwrite another
  named document or fall back to nonpersistent storage. See
  `docs/EASYFLOOR_DOCUMENTS.md` for format, dirty-state and platform limits.

- Put each tool in `lib/features/<tool>/`: screens and painters in `ui/`, engines/services/controllers in `logic/`.
- Keep app-wide styling/widgets in `lib/ui/`, shared validation in `lib/core/`, and startup in `lib/main.dart`. Home belongs in `lib/features/home/ui/`.
- Put feature-specific tests in `test/features/<tool>/` and shared UI tests in `test/ui/`. Cross-feature tests may remain at the test root.
- Use package imports across feature boundaries. Update all callers, tests, and documentation when moving files; do not leave duplicate implementations or obsolete forwarding files.

- UI collects input, calls an engine/service, and renders returned data.
- PVC Ceiling uses `lib/features/pvc_ceiling/logic/` for stock optimization,
  dimension validation, row widths, quantities and blade-aware tape readings.
  Keep those calculations out of its screens and painters. Its material drawing
  palette is defined in `BuildCalcColors` and exposed by `AppColors`; controls
  use the shared app theme, not a nested MaterialApp or feature-local theme.
  Shape inputs, lettered previews and calculated rows must share `PvcRoom`
  mappings. Never substitute default geometry for invalid inputs. Keep exact
  one-sided polygon row envelopes in logic, and clip rendered planks to the
  returned polygon; do not calculate an independent rectangular purchase count.
- Formulas, conversion factors, validation, placements, and material optimization belong in existing engines/services, not widgets or painters.
- 2D drawings, 3D drawings, and material summaries must use consistent calculation results. Do not independently recalculate quantities in drawings.
- Preserve units, precision, placement modes, gap accounting, and optimization behavior unless explicitly requested otherwise.
- Never substitute mock or random results for real calculated data.

## Change Checklist

1. Read relevant engines, screens, shared UI definitions, and tests.
2. Search all affected callers before changing a shared component or service.
3. Reuse existing helpers and dependencies; avoid new packages for small helpers.
4. Preserve numeric input rules, comma-separated custom drawer input, validation, and controller disposal.
5. Test calculation edge cases for logic changes and narrow-screen/text-scaling behavior for shared layout changes.
6. Format changed Dart files, then run the checks below.
7. Check a real target device when platform behavior matters. Widget tests do not prove compatibility with every phone, keyboard, font, or sensor.
8. Report changes, checks, and anything not verified. Do not promise perfect accuracy or universal compatibility.

```sh
dart format lib test
flutter analyze
flutter test
```

## Styling Audit

Run from the project root. No screen-file matches are expected for these raw style constructors:

```sh
rg -n '\bColors\.|\bColor\(|\bTextStyle\(|fontFamily:|BorderRadius\.|styleFrom\(' lib -g '*.dart' -g '!ui/**' -g '!lib/ui/**'
```

`rg` exits with status 1 for no matches; that is expected. This scan does not detect every visual override, including opacity, spacing, and shadows. It does not replace analysis or tests.

## Documentation

Update `README.md` and these rules when architecture or shared UI locations change. Document actual capabilities and limitations, not unverified guarantees.

## Construction Color Theme

The supplied `assets/Theme /` palette is integrated in `lib/core/theme/build_calc_colors.dart`; the active light Material theme lives in `lib/core/theme/app_theme.dart`. `lib/ui/app_theme.dart` exports it for existing callers. `AppColors` maps existing interface tokens to this palette, preserving distinct ceiling drawing/material colors. Update runtime tokens in core, not the reference asset files. Light mode is active; dark mode is not enabled because existing custom widgets use light-specific tokens.
