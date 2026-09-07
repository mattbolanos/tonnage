import ActivityKit
import SwiftUI
import WidgetKit

struct CompactWorkoutDuration: View {
  let context: ActivityViewContext<WorkoutActivityAttributes>

  @ScaledMetric(relativeTo: .caption2)
  private var timerWidth = LayoutMetrics.Size.liveActivityCompactTimerWidth

  var body: some View {
    if !context.state.isRunning {
      Image(systemName: "checkmark")
        .accessibilityLabel("Workout ended")
    } else if context.isStale {
      Image(systemName: "arrow.clockwise")
        .accessibilityLabel("Open Burthen to update")
    } else {
      // Use a system-recognized format so the clock keeps updating while
      // the app is suspended. Custom formatters and TimelineView cannot
      // reliably switch precision at a time threshold in a Live Activity.
      Text(
        .durationOffset(to: context.attributes.startedAt),
        format: .units(
          allowed: [.hours, .minutes],
          width: .narrow,
          maximumUnitCount: 2,
          fractionalPart: .hide(rounded: .towardZero)
        )
      )
        .monospacedDigit()
        .lineLimit(1)
        .font(.caption2.weight(.semibold))
        .multilineTextAlignment(.trailing)
        .frame(width: timerWidth)
    }
  }
}
