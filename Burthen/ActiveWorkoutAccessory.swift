//
//  ActiveWorkoutAccessory.swift
//  Burthen
//

import SwiftUI

struct ActiveWorkoutAccessory: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let workout: Workout
  let resume: () -> Void

  private var completedSetCount: Int {
    workout.workoutExercises.reduce(0) { count, exercise in
      count + exercise.exerciseSets.count { $0.isCompleted }
    }
  }

  var body: some View {
    Button(action: resume) {
      HStack(spacing: LayoutMetrics.Spacing.medium) {
        if !dynamicTypeSize.isAccessibilitySize {
          Image(systemName: "dumbbell.fill")
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
        }

        VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.extraSmall) {
          Text(dynamicTypeSize.isAccessibilitySize ? "Resume Workout" : workout.displayName)
            .font(.headline)
            .foregroundStyle(.primary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .center : .leading)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)

          if !dynamicTypeSize.isAccessibilitySize {
            Text("^[\(completedSetCount) set](inflect: true) completed")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        if !dynamicTypeSize.isAccessibilitySize {
          Spacer(minLength: LayoutMetrics.Spacing.small)

          Image(systemName: "chevron.up")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
      }
      .frame(maxWidth: .infinity, minHeight: LayoutMetrics.Size.resumeWorkoutButton)
      .padding(.horizontal, LayoutMetrics.Padding.horizontalContent)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Resume \(workout.displayName)")
    .accessibilityValue("^[\(completedSetCount) set](inflect: true) completed")
    .accessibilityHint("Expands your active workout. Your place in the workout is preserved.")
    .accessibilityInputLabels(["Resume Workout", workout.displayName])
    .accessibilityIdentifier("active-workout-accessory")
  }
}
