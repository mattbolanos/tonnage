//
//  ActiveWorkoutProgression.swift
//  Burthen
//

import Foundation

/// The next step offered after an exercise's working sets are complete.
enum ActiveWorkoutProgression: Equatable {
  case nextExercise(id: UUID, name: String)
  case reviewWorkout

  static func afterCompleting(_ currentExercise: WorkoutExercise) -> Self? {
    guard
      currentExercise.isCompleted,
      currentExercise.exercise != nil,
      let workout = currentExercise.workout,
      workout.status == .inProgress
    else { return nil }

    let orderedExercises = workout.orderedExercises
    guard let currentIndex = orderedExercises.firstIndex(where: {
      $0.id == currentExercise.id
    }) else { return nil }

    // Keep moving forward first, then return to any earlier unfinished work.
    let remainingExercises = orderedExercises.dropFirst(currentIndex + 1)
      + orderedExercises.prefix(currentIndex)
    guard
      let nextExercise = remainingExercises.first(where: {
        !$0.isCompleted && $0.exercise != nil
      }),
      let exercise = nextExercise.exercise
    else { return .reviewWorkout }

    return .nextExercise(id: nextExercise.id, name: exercise.name)
  }
}
