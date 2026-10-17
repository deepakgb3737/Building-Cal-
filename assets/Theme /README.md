# Building Calculator — Complete Color Design System

This package defines app-wide colors for a premium construction/building calculator.

## Files
- `build_calc_theme.dart`: Flutter Material 3 light and dark themes + reusable color tokens.
- `color_palette.json`: full semantic palette and category colors.

## Install
Copy `build_calc_theme.dart` into your project's theme folder (for example `lib/theme/build_calc_theme.dart`).

In `MaterialApp`:
```dart
import 'theme/build_calc_theme.dart';

MaterialApp(
  theme: BuildCalcTheme.light,
  darkTheme: BuildCalcTheme.dark,
  themeMode: ThemeMode.system,
  // ...
)
```

Use semantic tokens in widgets:
```dart
Container(
  color: BuildCalcColors.insulationBg,
  child: Icon(Icons.layers, color: BuildCalcColors.insulation),
)
```

## System rules
- Use theme surfaces and text styles for normal UI.
- Use the brand orange for the primary CTA, active navigation, and selected states.
- Use category colors only for icons, compact labels, and small highlights.
- Use status colors only when the meaning is success, warning, error, or information.
- Do not use a different random accent on each screen.
- For custom widgets, prefer `Theme.of(context).colorScheme` and the `BuildCalcColors` tokens.
- Verify contrast for any custom color/text pairing before release.

Note: The theme uses `CardThemeData`, compatible with current Flutter APIs. If your Flutter SDK is older and reports that this type is unavailable, replace `CardThemeData` with `CardTheme` as appropriate for that SDK version.
