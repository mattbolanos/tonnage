import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutLockScreenView: View {
  let context: ActivityViewContext<WorkoutActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.medium) {
      HStack(spacing: LayoutMetrics.Spacing.small) {
        BurthenActivityIcon()
          .accessibilityHidden(true)
        Text("Burthen")
          .font(.subheadline.weight(.semibold))
        Spacer()
        if !context.state.isRunning {
          Text("Workout ended")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if context.isStale {
          Text("Open Burthen to update")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      HStack(alignment: .center) {
        Text(context.attributes.workoutName)
          .font(.headline)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)

        if context.state.isRunning && !context.isStale {
          VStack(alignment: .trailing, spacing: LayoutMetrics.Spacing.extraSmall) {
            WorkoutElapsedTime(attributes: context.attributes)
              .font(.title2.weight(.semibold))
              .foregroundStyle(.pink)
              .multilineTextAlignment(.trailing)
            Text("Elapsed")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
    }
    .padding(LayoutMetrics.Padding.card)
  }
}
