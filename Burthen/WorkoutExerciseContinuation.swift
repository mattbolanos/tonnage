//
//  WorkoutExerciseContinuation.swift
//  Burthen
//

import SwiftUI

struct WorkoutExerciseContinuation: View {
  let progression: ActiveWorkoutProgression
  let onNextExercise: (UUID) -> Void
  let onReturnToWorkout: () -> Void

  var body: some View {
    Button(action: continueWorkout) {
      HStack(alignment: .firstTextBaseline) {
        switch progression {
        case .nextExercise(_, let name):
          Text("Next Exercise: \(Text(name).font(.body))")
        case .reviewWorkout:
          Text("Review Workout")
        }

        Spacer()

        Image(systemName: systemImage)
          .accessibilityHidden(true)
      }
      .font(.headline)
      .frame(maxWidth: .infinity, alignment: .leading)
      .multilineTextAlignment(.leading)
    }
    .buttonStyle(.borderedProminent)
    .tint(.pink)
    .controlSize(.large)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityInputLabels(accessibilityInputLabels)
    .accessibilityHint(accessibilityHint)
  }

  private var systemImage: String {
    switch progression {
    case .nextExercise: "arrow.right"
    case .reviewWorkout: "list.bullet"
    }
  }

  private var accessibilityLabel: String {
    switch progression {
    case .nextExercise(_, let name): "Next Exercise: \(name)"
    case .reviewWorkout: "Review Workout"
    }
  }

  private var accessibilityHint: String {
    switch progression {
    case .nextExercise: "Opens the next unfinished exercise."
    case .reviewWorkout: "Returns to the overview. Your workout stays active."
    }
  }

  private var accessibilityInputLabels: [String] {
    switch progression {
    case .nextExercise(_, let name): ["Next Exercise", "Next Exercise: \(name)"]
    case .reviewWorkout: ["Review Workout"]
    }
  }

  private func continueWorkout() {
    switch progression {
    case .nextExercise(let id, _): onNextExercise(id)
    case .reviewWorkout: onReturnToWorkout()
    }
  }
}
