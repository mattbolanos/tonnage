//
//  CompletedWorkoutVolumeDetails.swift
//  Burthen
//

import SwiftUI

struct CompletedWorkoutVolumeDetails: View {
  let workout: Workout

  var body: some View {
    DisclosureGroup {
      Text("Volume adds weight × repetitions for completed working sets. Warm-ups and sets without weight don’t contribute.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      ForEach(workout.orderedExercises) { workoutExercise in
        if let volume = workoutExercise.volumeLoad(in: workout.volumeLoadUnit) {
          LabeledContent(
            workoutExercise.exercise?.name ?? "Unavailable Exercise"
          ) {
            Text(volume.displayText)
              .monospacedDigit()
              .accessibilityLabel(volume.accessibilityText)
          }
        }
      }
    } label: {
      LabeledContent("Volume") {
        Text(workout.volumeLoad?.displayText ?? "Not recorded")
          .monospacedDigit()
          .accessibilityLabel(workout.volumeLoad?.accessibilityText ?? "Not recorded")
      }
    }
    .accessibilityIdentifier("summary-volume-details")
  }
}
