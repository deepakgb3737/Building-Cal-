# BuildCalc Agent Instructions

Read `RULES.md` and `README.md` before changing this project.

- Reuse shared UI definitions in `lib/ui/`; do not duplicate visual styles in screens.
- Keep formulas and validation in the existing engines/services.
- Preserve user changes and existing calculation behavior unless explicitly asked to change it.
- Check all affected callers and add regression tests for behavior changes.
- Run `flutter analyze` and `flutter test` after code changes. Report anything not verified.
- Do not claim all styling is centralized: local layout and legacy effects remain. Follow the boundary in `RULES.md`.

These instructions apply to the entire project.
