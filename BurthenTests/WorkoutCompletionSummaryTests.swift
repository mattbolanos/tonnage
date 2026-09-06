//
//  WorkoutCompletionSummaryTests.swift
//  BurthenTests
//

import Foundation
import Testing
@testable import Burthen

@MainActor
struct WorkoutCompletionSummaryTests {
  @Test
  func summaryIncludesCompletedWarmupsAndWorkingSetsOnly() throws {
    let workout = try Workout()
    let exercise = try workout.addExercise(
      Exercise(name: "Squat", loadMode: .bodyweight)
    )
    _ = try exercise.addSet(kind: .warmup, reps: 5)
    _ = try exercise.addSet(reps: 10)
    _ = try exercise.addDraftSet()

    let summary = WorkoutCompletionSummary(workout: workout)

    #expect(summary.completedSetCount == 2)
    #expect(summary.completedExerciseCount == 1)
    #expect(summary.unfinishedSetCount == 1)
    #expect(summary.omittedExerciseCount == 0)
  }

  @Test
  func exercisesWithoutCompletedSetsAreOmittedEvenWhenTheyHaveNoDrafts() throws {
    let workout = try Workout()
    let completed = try workout.addExercise(
      Exercise(name: "Push-up", loadMode: .bodyweight)
    )
    _ = try completed.addSet(reps: 10)
    let unfinished = try workout.addExercise(
      Exercise(name: "Pull-up", loadMode: .bodyweight)
    )
    _ = try unfinished.addDraftSet()
    _ = try workout.addExercise(
      Exercise(name: "Squat", loadMode: .bodyweight)
    )

    let summary = WorkoutCompletionSummary(workout: workout)

    #expect(summary.completedSetCount == 1)
    #expect(summary.completedExerciseCount == 1)
    #expect(summary.unfinishedSetCount == 1)
    #expect(summary.omittedExerciseCount == 2)
  }

  @Test
  func warmupOnlyCompletionAppearsInTheSummaryWithoutVolume() throws {
    let workout = try Workout()
    let exercise = try workout.addExercise(
      Exercise(name: "Squat", loadMode: .bodyweight)
    )
    _ = try exercise.addSet(kind: .warmup, reps: 5)
    _ = try exercise.addDraftSet()

    let summary = WorkoutCompletionSummary(workout: workout)

    #expect(workout.isCompletable)
    #expect(!exercise.isCompleted)
    #expect(summary.completedSetCount == 1)
    #expect(summary.completedExerciseCount == 1)
    #expect(summary.omittedExerciseCount == 0)
    #expect(workout.volumeLoad == nil)
  }

  @Test
  func finishingKeepsUnfinishedPlansWhileSummaryCountsStayTheSame() throws {
    let workout = try Workout(startedAt: .now.addingTimeInterval(-60))
    let exercise = try workout.addExercise(
      Exercise(name: "Squat", loadMode: .bodyweight)
    )
    _ = try exercise.addSet(reps: 10)
    let draft = try exercise.addDraftSet()
    let unfinished = try workout.addExercise(
      Exercise(name: "Lunge", loadMode: .bodyweight)
    )
    _ = try unfinished.addDraftSet()
    let before = WorkoutCompletionSummary(workout: workout)

    try workout.complete()

    let after = WorkoutCompletionSummary(workout: workout)
    #expect(after.completedSetCount == before.completedSetCount)
    #expect(after.completedExerciseCount == before.completedExerciseCount)
    #expect(after.unfinishedSetCount == 2)
    #expect(after.omittedExerciseCount == 1)
    #expect(exercise.exerciseSets.contains { $0.id == draft.id })
    #expect(workout.workoutExercises.contains { $0.id == unfinished.id })
    #expect(workout.templateExercisePlans.count == 2)
  }

  @Test
  func repeatedExercisesCountAsTheirSeparateWorkoutEntries() throws {
    let workout = try Workout()
    let exercise = try Exercise(name: "Squat", loadMode: .bodyweight)
    let first = try workout.addExercise(exercise)
    let second = try workout.addExercise(exercise)
    _ = try first.addSet(reps: 10)
    _ = try second.addSet(reps: 10)

    let summary = WorkoutCompletionSummary(workout: workout)

    #expect(summary.completedSetCount == 2)
    #expect(summary.completedExerciseCount == 2)
    #expect(summary.unfinishedSetCount == 0)
    #expect(summary.omittedExerciseCount == 0)
  }
}
