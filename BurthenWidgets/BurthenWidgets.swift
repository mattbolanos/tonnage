//
//  BurthenWidgets.swift
//  BurthenWidgets
//

import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

@main
struct BurthenWidgets: WidgetBundle {
  var body: some Widget {
    WorkoutActivityWidget()
  }
}

struct WorkoutActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
      WorkoutLockScreenView(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label {
            Text("Burthen")
              .font(.subheadline.weight(.semibold))
          } icon: {
            BurthenActivityIcon()
              .accessibilityHidden(true)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          CompactWorkoutDuration(context: context)
            .foregroundStyle(.pink)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.attributes.workoutName)
            .font(.headline)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      } compactLeading: {
        BurthenActivityIcon()
      } compactTrailing: {
        CompactWorkoutDuration(context: context)
          .foregroundStyle(.pink)
      } minimal: {
        BurthenActivityIcon()
      }
      .keylineTint(.pink)
    }
  }
}

extension WorkoutActivityAttributes {
  fileprivate static let preview = WorkoutActivityAttributes(
    workoutID: UUID(),
    workoutName: "Push Day",
    startedAt: .now.addingTimeInterval(-485)
  )
}

extension WorkoutActivityAttributes.ContentState {
  fileprivate static let preview = WorkoutActivityAttributes.ContentState(isRunning: true)
}

#Preview("Lock Screen", as: .content, using: WorkoutActivityAttributes.preview) {
  WorkoutActivityWidget()
} contentStates: {
  WorkoutActivityAttributes.ContentState.preview
}

#Preview(
  "Dynamic Island Compact",
  as: .dynamicIsland(.compact),
  using: WorkoutActivityAttributes.preview
) {
  WorkoutActivityWidget()
} contentStates: {
  WorkoutActivityAttributes.ContentState.preview
}

#Preview(
  "Dynamic Island Expanded",
  as: .dynamicIsland(.expanded),
  using: WorkoutActivityAttributes.preview
) {
  WorkoutActivityWidget()
} contentStates: {
  WorkoutActivityAttributes.ContentState.preview
}

#Preview(
  "Dynamic Island Minimal",
  as: .dynamicIsland(.minimal),
  using: WorkoutActivityAttributes.preview
) {
  WorkoutActivityWidget()
} contentStates: {
  WorkoutActivityAttributes.ContentState.preview
}

#Preview(
  "Lock Screen — Long Workout",
  as: .content,
  using: WorkoutActivityAttributes(
    workoutID: UUID(),
    workoutName: "Upper Body Strength and Conditioning",
    startedAt: .now.addingTimeInterval(-7_205)
  )
) {
  WorkoutActivityWidget()
} contentStates: {
  WorkoutActivityAttributes.ContentState.preview
  WorkoutActivityAttributes.ContentState(isRunning: false)
}

#Preview(
  "Dynamic Island — Long Duration",
  as: .dynamicIsland(.compact),
  using: WorkoutActivityAttributes(
    workoutID: UUID(),
    workoutName: "Push Day",
    startedAt: .now.addingTimeInterval(-28_740)
  )
) {
  WorkoutActivityWidget()
} contentStates: {
  WorkoutActivityAttributes.ContentState.preview
}

#Preview(
  "Dynamic Island — Ten Minutes",
  as: .dynamicIsland(.compact),
  using: WorkoutActivityAttributes(
    workoutID: UUID(),
    workoutName: "Push Day",
    startedAt: .now.addingTimeInterval(-600)
  )
) {
  WorkoutActivityWidget()
} contentStates: {
  WorkoutActivityAttributes.ContentState.preview
}

#Preview(
  "Dynamic Island — Hours and Minutes",
  as: .dynamicIsland(.compact),
  using: WorkoutActivityAttributes(
    workoutID: UUID(),
    workoutName: "Push Day",
    startedAt: .now.addingTimeInterval(-4_440)
  )
) {
  WorkoutActivityWidget()
} contentStates: {
  WorkoutActivityAttributes.ContentState.preview
}
