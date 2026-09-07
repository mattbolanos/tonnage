//
//  CompletedWorkoutExerciseCard.swift
//  Burthen
//

import SwiftUI

struct CompletedWorkoutExerciseCard: View {
  let workoutExercise: WorkoutExercise

  var body: some View {
    let orderedSets = workoutExercise.orderedSets.filter(\.isCompleted)

    VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.large) {
      Text(workoutExercise.exercise?.name ?? "Unavailable Exercise")
        .font(.headline)
        .foregroundStyle(.primary)

      if orderedSets.isEmpty {
        Text("No sets recorded")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.small) {
          ForEach(
            Array(orderedSets.enumerated()),
            id: \.element.id
          ) { index, exerciseSet in
            CompletedWorkoutSetRow(
              exerciseSet: exerciseSet,
              setNumber: index + 1
            )
          }
        }
      }
    }
    .padding(LayoutMetrics.Padding.card)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(
      .regular,
      in: .rect(cornerRadius: LayoutMetrics.CornerRadius.card)
    )
  }
}
