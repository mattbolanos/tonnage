//
//  CompletedWorkoutHeader.swift
//  Burthen
//

import SwiftUI

struct CompletedWorkoutHeader: View {
  let workout: Workout
  var showsCompletion = false

  var body: some View {
    let summary = WorkoutCompletionSummary(workout: workout)

    VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.small) {
      if showsCompletion {
        Label("Workout Complete", systemImage: "checkmark.circle.fill")
          .font(.headline)
          .foregroundStyle(.tint)
      }

      Text("^[\(summary.completedSetCount) set](inflect: true) completed")
        .font(.title2)
        .bold()
        .accessibilityIdentifier("summary-completed-sets")

      LabeledContent("Exercises") {
        Text(summary.completedExerciseCount, format: .number)
          .monospacedDigit()
      }
      .accessibilityIdentifier("summary-exercise-count")

      LabeledContent("Duration") {
        if let duration = workout.elapsedDuration() {
          Text(
            Duration.seconds(duration),
            format: .units(
              allowed: [.hours, .minutes, .seconds],
              width: .abbreviated,
              maximumUnitCount: 2
            )
          )
          .monospacedDigit()
        } else {
          Text("Not recorded")
        }
      }
      .accessibilityIdentifier("summary-duration")

      Divider()

      Text(workout.displayName)
        .font(.headline)
        .foregroundStyle(.secondary)

      Text(
        workout.startedAt,
        format: .dateTime
          .weekday(.wide)
          .month(.wide)
          .day()
          .hour()
          .minute()
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)

      if let notes = workout.notes {
        Text(notes)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, LayoutMetrics.Spacing.small)
    .listRowSeparator(.hidden)
    .listRowBackground(Color.clear)
  }
}
