# Native macOS UI Guidelines

These rules apply to every native SwiftUI feature added to IELTS Vocabulary Lab.

## Layout

- Build page content with `NativePage`. It provides the current available width and height as `NativeLayoutMetrics` through `EnvironmentValues.nativeLayout` and to the page builder.
- Use `NativeResponsiveStack` for rows that need to become vertical below 760 points. Use `NativeMetricGrid` for repeatable summary metrics.
- At less than 760 points of page width, controls and actions must wrap or stack; summary metrics use two columns below 920 points and four columns at 920 points and above.
- Prefer flexible frames and content-driven sizing. Fixed widths are appropriate only for small controls with a known fit; never make page or panel minimum widths add up to more than the supported window.
- Keep long content vertically scrollable. For side-by-side navigation/details, provide a push-style list-to-detail flow when the available width cannot support both panes.
- Adapt vertical density when the available page height is below 560 points. Avoid requiring a fixed-height page to expose primary actions.
- Keep text wrapping enabled. Use `fixedSize(horizontal: false, vertical: true)` for labels, prompts, and descriptions that would otherwise truncate.

## Appearance

- Use SwiftUI semantic styles (`.primary`, `.secondary`, `.tertiary`, `.tint`) and dynamic AppKit colors such as `windowBackgroundColor`, `controlBackgroundColor`, `textBackgroundColor`, and `separatorColor`.
- Use color as a restrained cue for page identity, progress, and status. Prefer a small accent in the shared page header and low-opacity semantic tints; keep large surfaces neutral and avoid assigning unrelated bright colors to every control.
- Do not use fixed black/white foregrounds or backgrounds for app surfaces. Status colors should retain readable contrast in both Aqua and Dark Aqua.
- Test the app's System, Light, and Dark appearance settings. Newly added views must inherit the current window appearance and respond when it changes.
- Respect `accessibilityReduceMotion` for nonessential transitions and animated charts.

## Verification Matrix

Check the main learning, vocabulary, speaking, writing, statistics, and settings flows at these window sizes:

| Window | Purpose |
| --- | --- |
| 740 × 500 | Minimum supported, compact and short |
| 900 × 620 | Narrow landscape |
| 1160 × 790 | Default |
| 1440 × 900 | Wide desktop |

For each size, confirm that controls remain visible and operable, text does not overlap or clip, horizontal content does not force window growth, and vertical scrolling reaches all actions. Repeat the visual check in Light and Dark appearance; check System appearance when macOS changes its appearance.
