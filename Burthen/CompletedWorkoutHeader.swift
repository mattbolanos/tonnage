//
//  CompletedWorkoutHeader.swift
//  Burthen
//

import SwiftUI

struct CompletedWorkoutHeader: View {
  let workout: Workout
  var showsCompletion = false

  var body: some View {
    VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.small) {
      if showsCompletion {
        Label("Workout Complete", systemImage: "checkmark.circle.fill")
          .font(.headline)
          .foregroundStyle(.tint)

        Text("^[\(completedSetCount) set](inflect: true) completed")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

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
      .font(.title3.weight(.semibold))

      if let notes = workout.notes {
        Text(notes)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      ActiveWorkoutStats(workout: workout)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, LayoutMetrics.Spacing.small)
    .listRowSeparator(.hidden)
    .listRowBackground(Color.clear)
    .accessibilityElement(children: .combine)
  }

  private var completedSetCount: Int {
    workout.workoutExercises.reduce(0) { count, exercise in
      count + exercise.exerciseSets.count { $0.isCompleted }
    }
  }
}
