import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutElapsedTime: View {
  let attributes: WorkoutActivityAttributes
  var showsHours = true

  var body: some View {
    // Timer text is rendered by the system even when the app and extension
    // are suspended. A TimelineView cannot drive a Live Activity clock.
    Text(
      timerInterval: attributes.elapsedTimeRange,
      countsDown: false,
      showsHours: showsHours
    )
    .monospacedDigit()
    .lineLimit(1)
    .accessibilityLabel("Elapsed time")
  }
}
