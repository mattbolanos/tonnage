don't execute xcode build or run commands unless asked to. the minimum ios deployment target here is 26.0, so no need for #available statements. always prefer native SwiftUI components.

Prefer the spacing supplied by native SwiftUI containers such as `Form`, `List`, and `Section`. When custom layout needs an explicit spacing, padding, inset, corner radius, or fixed alignment size, use `LayoutMetrics` from `Burthen/DesignSystem/LayoutMetrics.swift` instead of adding a one-off numeric value. Add a semantic alias there when a component-level value will be reused. Use `@ScaledMetric` for custom layout values that are visually tied to text size.

For list deletion and reordering, use native `ForEach.onDelete`, `ForEach.onMove`, and `EditButton` behavior consistently. Every trailing delete swipe action must use `allowsFullSwipe: false` and an icon-only `Label` with the `trash` system image and destructive role; keep a concise, specific title such as “Delete Set” for accessibility, but do not show that text visually. Preserve domain-specific deletion guards with `deleteDisabled` where needed.

consider guiding principles from https://benji.org/family-values when mulling over design + UX/UI decisions.

rather than default blue, choose apple system pink to match rest of repo.
