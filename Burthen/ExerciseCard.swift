//
//  ExerciseCard.swift
//  Burthen
//

import Foundation
import SwiftUI

struct ActiveWorkoutExerciseRoute: Hashable {
  let exerciseID: UUID
}

struct ActiveWorkoutExerciseSummary: Identifiable {
  let id: UUID
  let name: String
  let setCount: Int
  let completedSetCount: Int

  init(workoutExercise: WorkoutExercise) {
    id = workoutExercise.id
    name = workoutExercise.exercise?.name ?? "Unavailable Exercise"
    setCount = workoutExercise.workingSets.count
    completedSetCount = workoutExercise.completedWorkingSetCount
  }

  var setCountLabel: String {
    guard setCount > 0 else { return "No working sets" }

    let noun = setCount == 1 ? "set" : "sets"
    return "\(completedSetCount)/\(setCount) \(noun)"
  }

  var isCompleted: Bool {
    setCount > 0 && completedSetCount == setCount
  }

  var completionAccessibilityValue: String {
    guard setCount > 0 else { return "No working sets" }
    guard !isCompleted else { return "Completed" }

    let noun = setCount == 1 ? "set" : "sets"
    return "\(completedSetCount) of \(setCount) \(noun) completed"
  }

  var completionProgress: Double {
    guard setCount > 0 else { return 0 }
    return min(max(Double(completedSetCount) / Double(setCount), 0), 1)
  }
}

struct ExerciseCard: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let exercise: ActiveWorkoutExerciseSummary

  var body: some View {
    NavigationLink(
      value: ActiveWorkoutExerciseRoute(exerciseID: exercise.id)
    ) {
      HStack(spacing: LayoutMetrics.Spacing.medium) {
        VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.extraSmall) {
          Text(exercise.name)
            .font(.headline)
            .foregroundStyle(.primary)
            .lineLimit(2)
          Text(exercise.setCountLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
            .contentTransition(reduceMotion ? .identity : .numericText())
            .animation(reduceMotion ? nil : .smooth, value: exercise.completedSetCount)
        }

        Spacer(minLength: LayoutMetrics.Spacing.small)

        CircularProgress(value: exercise.completionProgress)
          .tint(.accentColor)
          .accessibilityHidden(true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
      .accessibilityElement(children: .combine)
    }
    .opacity(exercise.isCompleted ? 0.5 : 1)
    .accessibilityValue(exercise.completionAccessibilityValue)
    .padding(LayoutMetrics.Padding.card)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(
      .regular.interactive(),
      in: .rect(cornerRadius: LayoutMetrics.CornerRadius.card)
    )
  }
}
