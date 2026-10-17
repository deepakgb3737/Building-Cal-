# Material Calculators

## Scope

Four original BuildCalc tools: Paint, Flooring Tiles, Concrete Volume, and Plaster.
Each has a feature-local `logic/` engine and `ui/` screen. They share only form
rendering (`lib/ui/material_estimate_screen.dart`) and quantity validation/pack
rounding (`lib/core/material_quantity.dart`). Existing calculators are unchanged.

These are quantity estimates, not structural design, regulatory compliance,
manufacturer guarantees, or optimal cutting plans. All work offline.

## Formulas And Units

`A = length_m * width_or_height_m - excluded_area_m2`

Excluded area must be non-negative and smaller than the gross rectangular area.
An allowance `p` is applied as `quantity * (1 + p / 100)`.

| Tool | Base quantity | Purchase quantity |
| --- | --- | --- |
| Paint | `A * coats / coverage_m2_per_litre_per_coat` litres | Whole containers rounded up after allowance |
| Flooring Tiles | `A / (tile_length_mm * tile_width_mm / 1000000)` tiles | Tiles rounded up after allowance, then whole boxes rounded up |
| Concrete Volume | `length_m * width_m * depth_mm / 1000` cubic metres | Volume including allowance, no assumed supplier increment |
| Plaster | `A * kg_per_m2_at_10mm * thickness_mm / 10` kilograms | Whole bags rounded up after allowance |

Never use rounded display values as inputs to later calculations. Pack rounding
ignores absolute ratio differences below `1e-10` at positive integer boundaries
to avoid floating-point extra packs. A tiny positive requirement still needs one
pack. A computed pack count above one billion is rejected.

Dimensions in metres are limited to 1000 per axis. Tile dimensions in millimetres
are limited to 10000, concrete depth to 10000 mm, plaster thickness to 100 mm,
coats to 1-20, box count to 1-10000 tiles, and allowance to 0-100%. These are app
input bounds, not recommendations for acceptable construction dimensions.
Inputs must be finite, and quantities/rates/pack sizes must be positive.

## Explicit Assumptions

- Paint: one rectangular surface, same declared coverage for every coat. Enter
  the product coverage; no automatic absorption/primer/colour multiplier.
- Flooring: area-based estimate. Joint widths, diagonal layouts, edge piece
  counts and offcut reuse are not calculated. Adjust allowance for the layout.
- Concrete: uniform rectangular solid. No mix design, reinforcement, strength,
  load capacity, excavated soil allowance or assumed cement/sand quantities.
- Plaster: dry bagged product with consumption declared at 10 mm. Linear scaling
  is an estimate; use manufacturer thickness limits and average actual depth.
- Initial allowances (10%, concrete 5%), two paint coats, 600 mm tiles, four tiles
  per box, 4 L containers, 10 mm plaster, and 25 kg bags are editable conveniences.
  They are not universal material specifications. Paint and plaster product rates
  intentionally have no default and must be supplied by the user.

The UI labels every unit, shows allowances and quantity breakdowns, supports
copying the inputs/result/limitations, and clears results when inputs change.

## Reference Review

Reviewed on 2026-10-10:

- [probrab1](https://github.com/antilopa1144-tech/probrab1): calculator categories
  and the `calculate_paint_universal.dart`, `calculate_tile.dart`,
  `calculate_concrete_universal.dart` and `calculate_plaster.dart` use cases.
  No license file was found in the inspected repository tree. No code was copied.
- [Dulux paint calculation guidance](https://www.dulux.co.uk/en/expert-help/how-much-paint-do-you-need):
  calculate surface area and use the selected product's coverage and coats.
- [Knauf plaster guidance](https://knauf.com/nl-BE/toepassingen/muur):
  product-specific consumption is tied to declared thickness and bag size.

The reference app's regional material tables and extra coefficients are not
treated as universally applicable. BuildCalc uses dimensional formulas with
visible user-supplied product rates instead.

## Checks

Unit tests cover all four formulas, unit changes, allowance and packaging
rounding, invalid inputs, and integer-boundary floating-point behaviour. Widget
tests cover 320 x 640 at 1.5 text scale, copying, stale-result clearing, validation,
and all four Home routes. Physical-device input/rendering still needs verification.
