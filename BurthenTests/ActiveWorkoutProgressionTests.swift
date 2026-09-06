//
//  ActiveWorkoutProgressionTests.swift
//  BurthenTests
//

import Foundation
import Testing
@testable import Burthen

@MainActor
struct ActiveWorkoutProgressionTests {
  @Test
  func nextExerciseFollowsWorkoutOrderAndSkipsCompletedExercises() throws {
    let workout = try Workout()
    let next = try addExercise(to: workout, named: "Pull-up")
    let earlier = try addExercise(to: workout, named: "Push-up")
    let current = try addExercise(to: workout, named: "Squat", completed: true)
    let completed = try addExercise(to: workout, named: "Lunge", completed: true)
    workout.updateExerciseOrder([earlier, current, completed, next])

    #expect(
      ActiveWorkoutProgression.afterCompleting(current)
        == .nextExercise(id: next.id, name: "Pull-up")
    )
  }

  @Test
  func earlierUnfinishedExerciseIsOfferedAfterLaterExercisesAreComplete() throws {
    let workout = try Workout()
    let earlier = try addExercise(to: workout, named: "Push-up")
    let current = try addExercise(to: workout, named: "Squat", completed: true)
    _ = try addExercise(to: workout, named: "Lunge", completed: true)

    #expect(
      ActiveWorkoutProgression.afterCompleting(current)
        == .nextExercise(id: earlier.id, name: "Push-up")
    )
  }

  @Test
  func finishedWorkingSetsOfferReviewWithoutEndingTheWorkout() throws {
    let workout = try Workout()
    let current = try addExercise(to: workout, named: "Squat", completed: true)
    _ = try current.addSet(kind: .warmup, reps: 5, completedAt: nil)
    _ = try addExercise(to: workout, named: "Push-up", completed: true)

    #expect(ActiveWorkoutProgression.afterCompleting(current) == .reviewWorkout)
    #expect(workout.status == .inProgress)
    #expect(workout.endedAt == nil)
  }

  @Test
  func addingOrReopeningAWorkingSetHidesTheNextStep() throws {
    let workout = try Workout()
    let current = try addExercise(to: workout, named: "Squat", completed: true)
    _ = try addExercise(to: workout, named: "Push-up")

    let addedSet = try current.addDraftSet()
    #expect(ActiveWorkoutProgression.afterCompleting(current) == nil)

    addedSet.completedAt = .now
    #expect(ActiveWorkoutProgression.afterCompleting(current) != nil)

    current.orderedSets.first?.completedAt = nil
    #expect(ActiveWorkoutProgression.afterCompleting(current) == nil)
  }

  @Test
  func emptyAndWarmupOnlyExercisesDoNotOfferACompletionStep() throws {
    let workout = try Workout()
    let exercise = try Exercise(name: "Squat", loadMode: .bodyweight)
    let current = try workout.addExercise(exercise)

    #expect(ActiveWorkoutProgression.afterCompleting(current) == nil)

    _ = try current.addSet(kind: .warmup, reps: 5)
    #expect(ActiveWorkoutProgression.afterCompleting(current) == nil)
  }

  @Test
  func unavailableExerciseIsSkipped() throws {
    let workout = try Workout()
    let current = try addExercise(to: workout, named: "Squat", completed: true)
    let unavailable = try addExercise(to: workout, named: "Lunge")
    let next = try addExercise(to: workout, named: "Push-up")
    unavailable.exercise = nil

    #expect(
      ActiveWorkoutProgression.afterCompleting(current)
        == .nextExercise(id: next.id, name: "Push-up")
    )
  }

  @Test
  func repeatedExercisesUseTheirWorkoutEntryIdentity() throws {
    let workout = try Workout()
    let exercise = try Exercise(name: "Squat", loadMode: .bodyweight)
    let current = try workout.addExercise(exercise)
    _ = try current.addSet(reps: 5)
    let next = try workout.addExercise(exercise)
    _ = try next.addDraftSet()

    #expect(
      ActiveWorkoutProgression.afterCompleting(current)
        == .nextExercise(id: next.id, name: "Squat")
    )
  }

  @Test
  func completedWorkoutsAndRemovedEntriesDoNotOfferAContinuation() throws {
    let workout = try Workout()
    let current = try addExercise(to: workout, named: "Squat", completed: true)
    workout.removeExercise(current)

    #expect(ActiveWorkoutProgression.afterCompleting(current) == nil)

    let remaining = try addExercise(to: workout, named: "Push-up", completed: true)
    try workout.complete()
    #expect(ActiveWorkoutProgression.afterCompleting(remaining) == nil)
  }

  private func addExercise(
    to workout: Workout,
    named name: String,
    completed: Bool = false
  ) throws -> WorkoutExercise {
    let exercise = try Exercise(name: name, loadMode: .bodyweight)
    let entry = try workout.addExercise(exercise)
    if completed {
      _ = try entry.addSet(reps: 5)
    } else {
      _ = try entry.addDraftSet()
    }
    return entry
  }
}
