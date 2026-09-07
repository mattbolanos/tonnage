//
//  WorkoutCompletionSummary.swift
//  Burthen
//

/// The work shown in a completed workout's summary. Finishing a workout keeps
/// its planned sets, but only completed sets appear in the summary.
struct WorkoutCompletionSummary {
  let completedSetCount: Int
  let completedExerciseCount: Int
  let unfinishedSetCount: Int
  let omittedExerciseCount: Int

  init(workout: Workout) {
    let exercises = workout.workoutExercises
    completedSetCount = exercises.reduce(0) { count, exercise in
      count + exercise.exerciseSets.count { $0.isCompleted }
    }
    completedExerciseCount = exercises.count { exercise in
      exercise.exerciseSets.contains { $0.isCompleted }
    }
    unfinishedSetCount = exercises.reduce(0) { count, exercise in
      count + exercise.exerciseSets.count { !$0.isCompleted }
    }
    omittedExerciseCount = exercises.count - completedExerciseCount
  }
}
