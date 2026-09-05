//
//  BurthenTests.swift
//  BurthenTests
//
//  Created by Matt Bolaños on 7/25/26.
//

import Foundation
import SwiftData
import Testing
@testable import Burthen

@MainActor
struct BurthenTests {
  @Test
  func volumeLoadFavorsMoreRepsWhenTheProductIsGreater() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let benchEntry = try workout.addExercise(benchPress)

    let twelveByForty = try benchEntry.addSet(
      reps: 12,
      weight: Decimal(40),
      weightUnit: .pounds
    )
    let fiveByFortyFive = try benchEntry.addSet(
      reps: 5,
      weight: Decimal(45),
      weightUnit: .pounds
    )

    #expect(twelveByForty.volumeLoad?.value == Decimal(480))
    #expect(fiveByFortyFive.volumeLoad?.value == Decimal(225))
    #expect(
      twelveByForty.volumeLoad?.value ?? .zero
        > fiveByFortyFive.volumeLoad?.value ?? .zero
    )
  }

  @Test
  func workoutLoadSumsWeightedWorkingSetsOnly() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let pushUp = try Exercise(
      name: "Push-up",
      loadMode: .bodyweight
    )
    let workout = try Workout()
    let benchEntry = try workout.addExercise(benchPress)
    let pushUpEntry = try workout.addExercise(pushUp)

    try benchEntry.addSet(reps: 12, weight: 40, weightUnit: .pounds)
    try benchEntry.addSet(reps: 5, weight: 45, weightUnit: .pounds)
    try benchEntry.addSet(kind: .warmup, reps: 10, weight: 20, weightUnit: .pounds)
    try pushUpEntry.addSet(reps: 20)
    try pushUpEntry.addSet(reps: 5, weight: 10, weightUnit: .pounds)

    let load = workout.volumeLoad(in: .pounds)

    #expect(benchEntry.volumeLoad == VolumeLoad(value: 705, unit: .pounds))
    #expect(load == VolumeLoad(value: 755, unit: .pounds))
    #expect(workout.volumeLoad == load)
    #expect(workout.volumeLoad(for: benchPress.id, in: .pounds)?.value == 705)
    #expect(workout.volumeLoad(for: pushUp.id, in: .pounds)?.value == 50)
  }

  @Test
  func warmupSetsNeverContributeToVolumeLoad() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let entry = try workout.addExercise(benchPress)
    let warmup = try entry.addSet(
      kind: .warmup,
      reps: 10,
      weight: 45,
      weightUnit: .pounds
    )

    #expect(warmup.volumeLoad == nil)
    #expect(entry.volumeLoad(in: .pounds) == nil)
    #expect(workout.volumeLoad(in: .pounds) == nil)
  }

  @Test
  func incompleteSetsDoNotContributeToVolumeLoad() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let entry = try workout.addExercise(benchPress)
    let completedSet = try entry.addSet(
      reps: 10,
      weight: 40,
      weightUnit: .pounds
    )
    let incompleteSet = try entry.addSet(
      reps: 10,
      weight: 50,
      weightUnit: .pounds,
      completedAt: nil
    )

    #expect(completedSet.volumeLoad?.value == 400)
    #expect(incompleteSet.volumeLoad == nil)
    #expect(entry.volumeLoad?.value == 400)
    #expect(workout.volumeLoad?.value == 400)
  }

  @Test
  func incompleteSetsDoNotMakeAWorkoutCompletable() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let entry = try workout.addExercise(benchPress)
    _ = try entry.addDraftSet()

    #expect(!workout.isCompletable)
    #expect(throws: WorkoutModelError.workoutHasNoSets) {
      try workout.complete()
    }

    _ = try entry.addSet(
      reps: 10,
      weight: 40,
      weightUnit: .pounds
    )

    #expect(workout.isCompletable)
    try workout.complete()
    #expect(workout.status == .completed)
  }

  @Test
  func exerciseCompletesWhenAllWorkingSetsAreCompleted() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let entry = try workout.addExercise(benchPress)
    _ = try entry.addSet(
      kind: .warmup,
      reps: 10,
      weight: 20,
      weightUnit: .pounds,
      completedAt: nil
    )
    let firstWorkingSet = try entry.addSet(
      reps: 10,
      weight: 40,
      weightUnit: .pounds
    )
    _ = try entry.addSet(
      reps: 8,
      weight: 40,
      weightUnit: .pounds,
      completedAt: nil
    )

    #expect(entry.completedWorkingSetCount == 1)
    #expect(!entry.isCompleted)

    entry.orderedSets.last?.completedAt = .now

    #expect(firstWorkingSet.isCompleted)
    #expect(entry.completedWorkingSetCount == 2)
    #expect(entry.isCompleted)
  }

  @Test
  func bodyweightOnlyWorkoutHasNoVolumeLoad() throws {
    let pushUp = try Exercise(name: "Push-up", loadMode: .bodyweight)
    let workout = try Workout()
    let entry = try workout.addExercise(pushUp)
    try entry.addSet(reps: 20)

    #expect(workout.volumeLoad(in: .pounds) == nil)
  }

  @Test
  func volumeLoadNormalizesMixedUnits() throws {
    let squat = try Exercise(name: "Squat", loadMode: .externalResistance)
    let workout = try Workout()
    let entry = try workout.addExercise(squat)
    try entry.addSet(reps: 10, weight: 100, weightUnit: .pounds)
    try entry.addSet(reps: 10, weight: 10, weightUnit: .kilograms)

    let expected = Decimal(1_000) + WeightUnit.kilograms.convert(100, to: .pounds)

    #expect(entry.volumeLoad == VolumeLoad(value: expected, unit: .pounds))
    #expect(workout.volumeLoad(in: .pounds)?.value == expected)
    #expect(workout.volumeLoad == VolumeLoad(value: expected, unit: .pounds))
  }

  @Test
  func invalidSetsAreRejectedBeforeJoiningTheWorkout() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let entry = try workout.addExercise(benchPress)

    #expect(throws: WorkoutModelError.missingWeight) {
      try entry.addSet(reps: 5)
    }
    #expect(throws: WorkoutModelError.invalidWeightPrecision) {
      try entry.addSet(reps: 5, weight: Decimal(string: "42.25"), weightUnit: .pounds)
    }
    #expect(entry.exerciseSets.isEmpty)
  }

  @Test
  func workoutLifecycleUsesTimestampsWithoutPersistingElapsedSeconds() throws {
    let start = Date(timeIntervalSince1970: 1_000)
    let workout = try Workout(startedAt: start, timeZoneIdentifier: "America/New_York")

    #expect(workout.elapsedDuration(at: start.addingTimeInterval(90)) == 90)
    #expect(throws: WorkoutModelError.workoutHasNoSets) {
      try workout.complete(at: start.addingTimeInterval(120))
    }

    let pushUp = try Exercise(name: "Push-up", loadMode: .bodyweight)
    let entry = try workout.addExercise(pushUp)
    try entry.addSet(reps: 10)
    try workout.complete(at: start.addingTimeInterval(120))

    #expect(workout.status == .completed)
    #expect(workout.elapsedDuration() == 120)
    #expect(throws: WorkoutModelError.workoutAlreadyCompleted) {
      try workout.complete()
    }
  }

  @Test
  func unnamedWorkoutUsesStartTimeForItsDisplayName() throws {
    let timeZone = try #require(TimeZone(identifier: "America/New_York"))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone

    func workoutStarted(at hour: Int) throws -> Workout {
      let startedAt = try #require(
        calendar.date(
          from: DateComponents(year: 2026, month: 8, day: 4, hour: hour)
        )
      )
      return try Workout(
        startedAt: startedAt,
        timeZoneIdentifier: timeZone.identifier
      )
    }

    let morning = try workoutStarted(at: 11)
    let afternoon = try workoutStarted(at: 12)
    let evening = try workoutStarted(at: 17)
    let named = try Workout(
      name: "Push Day",
      startedAt: morning.startedAt,
      timeZoneIdentifier: timeZone.identifier
    )

    #expect(morning.displayName == "Morning Lift")
    #expect(afternoon.displayName == "Afternoon Lift")
    #expect(evening.displayName == "Evening Lift")
    #expect(named.displayName == "Push Day")
  }

  @Test
  func workoutActivityPayloadRoundTripsThroughCodable() throws {
    let attributes = WorkoutActivityAttributes(
      workoutID: UUID(uuidString: "B852A04B-E6C9-49CC-B30B-97707E452EBE")!,
      workoutName: "Push Day",
      startedAt: Date(timeIntervalSince1970: 1_000)
    )
    let state = WorkoutActivityAttributes.ContentState(isRunning: true)

    #expect(attributes.elapsedTimeRange.lowerBound == attributes.startedAt)
    #expect(
      attributes.elapsedTimeRange.upperBound
        == attributes.startedAt.addingTimeInterval(8 * 60 * 60)
    )

    let encodedAttributes = try JSONEncoder().encode(attributes)
    let encodedState = try JSONEncoder().encode(state)

    #expect(
      try JSONDecoder().decode(
        WorkoutActivityAttributes.self,
        from: encodedAttributes
      ) == attributes
    )
    #expect(
      try JSONDecoder().decode(
        WorkoutActivityAttributes.ContentState.self,
        from: encodedState
      ) == state
    )
  }

  @Test
  func manualCompletedWorkoutMayHaveUnknownDuration() throws {
    let workout = try Workout(startedAt: .now)
    let pushUp = try Exercise(name: "Push-up", loadMode: .bodyweight)
    let entry = try workout.addExercise(pushUp)
    try entry.addSet(reps: 10)

    try workout.complete(at: nil)

    #expect(workout.status == .completed)
    #expect(workout.endedAt == nil)
    #expect(workout.elapsedDuration() == nil)
  }

  @Test
  func templateCreatesAnIndependentWorkoutSnapshot() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let squat = try Exercise(name: "Squat", loadMode: .externalResistance)
    let template = try WorkoutTemplate(name: "Push Day")
    try template.addExercise(benchPress, plannedWorkingSetCount: 3)

    let workout = try template.makeWorkout()
    try template.addExercise(squat, plannedWorkingSetCount: 4)

    #expect(workout.sourceTemplate === template)
    #expect(workout.workoutExercises.count == 1)
    #expect(workout.orderedExercises.first?.exercise === benchPress)
    #expect(workout.orderedExercises.first?.plannedWorkingSetCount == 3)
    #expect(workout.workoutExercises.first?.exerciseSets.isEmpty == true)
  }

  @Test
  func workoutCanCreateATemplateWithoutCopyingSetValues() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let entry = try workout.addExercise(benchPress)
    try entry.addSet(reps: 12, weight: 40, weightUnit: .pounds)
    try entry.addSet(reps: 10, weight: 45, weightUnit: .pounds)
    try entry.addSet(kind: .warmup, reps: 10, weight: 20, weightUnit: .pounds)

    let template = try workout.makeTemplate(named: "Bench Day")

    #expect(template.templateExercises.count == 1)
    #expect(template.templateExercises.first?.plannedWorkingSetCount == 2)
  }

  @Test
  func workoutTemplatePlansPreserveOrderAndCurrentWorkingSetCounts() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let pullUp = try Exercise(name: "Pull-up", loadMode: .bodyweight)
    let workout = try Workout()
    let benchEntry = try workout.addExercise(
      benchPress,
      plannedWorkingSetCount: 5
    )
    _ = try workout.addExercise(
      pullUp,
      plannedWorkingSetCount: 4
    )
    try benchEntry.addSet(reps: 10, weight: 45, weightUnit: .pounds)
    try benchEntry.addSet(reps: 8, weight: 50, weightUnit: .pounds)
    try benchEntry.addSet(
      kind: .warmup,
      reps: 10,
      weight: 20,
      weightUnit: .pounds
    )

    let plans = workout.templateExercisePlans

    #expect(plans.map(\.exercise.name) == ["Bench Press", "Pull-up"])
    #expect(plans.map(\.plannedWorkingSetCount) == [2, 4])
  }

  @Test
  func blankWorkoutTemplateSeedUsesTheSharedWorkingSetDefault() throws {
    let squat = try Exercise(name: "Squat", loadMode: .externalResistance)
    let pullUp = try Exercise(name: "Pull-up", loadMode: .bodyweight)

    let seed = WorkoutTemplateSeed(exercises: [squat, pullUp])

    #expect(seed.exercisePlans.map(\.exercise.name) == ["Squat", "Pull-up"])
    #expect(
      seed.exercisePlans.map(\.plannedWorkingSetCount)
        == [TrainingDefaults.workingSetCount, TrainingDefaults.workingSetCount]
    )
  }

  @Test
  func storeEnforcesOneActiveWorkoutAndUniqueActiveNames() throws {
    let container = try makeContainer()
    let store = TrainingDataStore(modelContext: container.mainContext)

    try store.startWorkout()
    #expect(throws: WorkoutModelError.activeWorkoutExists) {
      try store.startWorkout()
    }

    try store.createExercise(name: "Bench Press", loadMode: .externalResistance)
    #expect(throws: WorkoutModelError.duplicateExerciseName) {
      try store.createExercise(name: "bench press", loadMode: .externalResistance)
    }

    try store.createTemplate(name: "Push Day")
    #expect(throws: WorkoutModelError.duplicateTemplateName) {
      try store.createTemplate(name: "push day")
    }
  }

  @Test
  func storeCreatesTemplateWithAnOrderedExercisePlan() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let store = TrainingDataStore(modelContext: context)
    let squat = try store.createExercise(
      name: "Squat",
      loadMode: .externalResistance
    )
    let pullUp = try store.createExercise(
      name: "Pull-up",
      loadMode: .bodyweight
    )

    let template = try store.createTemplate(
      name: "Full Body",
      notes: "  Strength day  ",
      exercises: [
        TemplateExercisePlan(
          exercise: squat,
          plannedWorkingSetCount: 4
        ),
        TemplateExercisePlan(
          exercise: pullUp,
          plannedWorkingSetCount: 3
        ),
      ]
    )
    try context.save()

    #expect(template.name == "Full Body")
    #expect(template.notes == "Strength day")
    #expect(template.orderedExercises.map(\.position) == [0, 1])
    #expect(
      template.orderedExercises.compactMap { $0.exercise?.name }
        == ["Squat", "Pull-up"]
    )
    #expect(
      template.orderedExercises.map(\.plannedWorkingSetCount)
        == [4, 3]
    )
    #expect(try context.fetchCount(FetchDescriptor<TemplateExercise>()) == 2)
  }

  @Test
  func updatingTemplateReplacesItsExercisePlan() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let store = TrainingDataStore(modelContext: context)
    let benchPress = try store.createExercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let row = try store.createExercise(
      name: "Barbell Row",
      loadMode: .externalResistance
    )
    let template = try store.createTemplate(
      name: "Upper Body",
      exercises: [
        TemplateExercisePlan(
          exercise: benchPress,
          plannedWorkingSetCount: 3
        ),
        TemplateExercisePlan(
          exercise: row,
          plannedWorkingSetCount: 4
        ),
      ]
    )
    try context.save()

    let updateDate = Date(timeIntervalSince1970: 4_000)
    try store.updateTemplate(
      template,
      name: "  Pull Day  ",
      notes: "  Keep reps controlled  ",
      exercises: [
        TemplateExercisePlan(
          exercise: row,
          plannedWorkingSetCount: 5
        ),
      ],
      at: updateDate
    )
    try context.save()

    #expect(template.name == "Pull Day")
    #expect(template.notes == "Keep reps controlled")
    #expect(template.updatedAt == updateDate)
    #expect(template.orderedExercises.count == 1)
    #expect(template.orderedExercises.first?.exercise === row)
    #expect(template.orderedExercises.first?.plannedWorkingSetCount == 5)
    #expect(try context.fetchCount(FetchDescriptor<TemplateExercise>()) == 1)
  }

  @Test
  func restoringTemplatePreservesUniqueActiveNames() throws {
    let container = try makeContainer()
    let store = TrainingDataStore(modelContext: container.mainContext)
    let archivedTemplate = try store.createTemplate(name: "Push Day")
    store.archive(archivedTemplate)
    _ = try store.createTemplate(name: "push day")

    #expect(throws: WorkoutModelError.duplicateTemplateName) {
      try store.restore(archivedTemplate)
    }
    #expect(archivedTemplate.isArchived)
  }

  @Test
  func templateRejectsDuplicateExercisesBeforeInsertion() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let store = TrainingDataStore(modelContext: context)
    let squat = try store.createExercise(
      name: "Squat",
      loadMode: .externalResistance
    )
    let duplicatePlan = TemplateExercisePlan(
      exercise: squat,
      plannedWorkingSetCount: 3
    )

    #expect(throws: WorkoutModelError.duplicateExerciseInTemplate) {
      try store.createTemplate(
        name: "Leg Day",
        exercises: [duplicatePlan, duplicatePlan]
      )
    }
    #expect(try context.fetchCount(FetchDescriptor<WorkoutTemplate>()) == 0)
  }

  @Test
  func referencedTemplateIsArchivedInsteadOfDeleted() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let store = TrainingDataStore(modelContext: context)
    let exercise = try store.createExercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let template = try store.createTemplate(name: "Push Day")
    try template.addExercise(exercise, plannedWorkingSetCount: 3)
    let workout = try store.startWorkout(from: template)
    try context.save()

    store.remove(template)
    try context.save()

    #expect(template.isArchived)
    #expect(workout.sourceTemplate === template)
    #expect(try context.fetchCount(FetchDescriptor<WorkoutTemplate>()) == 1)
  }

  @Test
  func deletingWorkoutCascadesToLoggedChildren() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let exercise = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let workoutExercise = try workout.addExercise(exercise)
    try workoutExercise.addSet(reps: 12, weight: 40, weightUnit: .pounds)
    context.insert(exercise)
    context.insert(workout)
    try context.save()

    context.delete(workout)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<ExerciseSet>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
  }

  @Test
  func usedExerciseClassificationIsLocked() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let entry = try workout.addExercise(benchPress)
    try entry.addSet(reps: 12, weight: 40, weightUnit: .pounds)

    #expect(throws: WorkoutModelError.exerciseClassificationInUse) {
      try benchPress.updateClassification(
        loadMode: .bodyweight,
        repetitionMode: .standard
      )
    }
  }

  @Test
  func updatingExerciseRenamesAndChangesTracking() throws {
    let container = try makeContainer()
    let store = TrainingDataStore(modelContext: container.mainContext)
    let exercise = try store.createExercise(
      name: "Goblet Squat",
      loadMode: .externalResistance
    )
    let updateDate = Date(timeIntervalSince1970: 2_000)

    try store.updateExercise(
      exercise,
      name: "  Split Squat  ",
      loadMode: .bodyweight,
      repetitionMode: .perSide,
      at: updateDate
    )

    #expect(exercise.name == "Split Squat")
    #expect(exercise.loadMode == .bodyweight)
    #expect(exercise.repetitionMode == .perSide)
    #expect(exercise.updatedAt == updateDate)
  }

  @Test
  func exerciseStoresAndUpdatesAnOptionalStartingWorkingWeight() throws {
    let container = try makeContainer()
    let store = TrainingDataStore(modelContext: container.mainContext)
    let exercise = try store.createExercise(
      name: "Goblet Squat",
      loadMode: .externalResistance,
      startingWorkingWeight: 24,
      startingWorkingWeightUnit: .kilograms
    )
    let updateDate = Date(timeIntervalSince1970: 2_000)

    try store.updateExercise(
      exercise,
      name: exercise.name,
      loadMode: exercise.loadMode,
      repetitionMode: exercise.repetitionMode,
      startingWorkingWeight: 55,
      startingWorkingWeightUnit: .pounds,
      at: updateDate
    )

    #expect(exercise.startingWorkingWeight == 55)
    #expect(exercise.startingWorkingWeightUnit == .pounds)
    #expect(exercise.updatedAt == updateDate)
    #expect(throws: WorkoutModelError.invalidWeight) {
      try exercise.updateStartingWorkingWeight(0)
    }
    #expect(throws: WorkoutModelError.invalidWeightPrecision) {
      try exercise.updateStartingWorkingWeight(Decimal(string: "42.25"))
    }
  }

  @Test
  func duplicateExerciseRenameDoesNotPartiallyUpdate() throws {
    let container = try makeContainer()
    let store = TrainingDataStore(modelContext: container.mainContext)
    let benchPress = try store.createExercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    _ = try store.createExercise(
      name: "Push-up",
      loadMode: .bodyweight
    )

    #expect(throws: WorkoutModelError.duplicateExerciseName) {
      try store.updateExercise(
        benchPress,
        name: "push-up",
        loadMode: .bodyweight,
        repetitionMode: .perSide
      )
    }
    #expect(benchPress.name == "Bench Press")
    #expect(benchPress.loadMode == .externalResistance)
    #expect(benchPress.repetitionMode == .standard)
  }

  @Test
  func usedExerciseCanBeRenamedWithoutChangingTracking() throws {
    let container = try makeContainer()
    let store = TrainingDataStore(modelContext: container.mainContext)
    let exercise = try store.createExercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try store.startWorkout()
    let entry = try workout.addExercise(exercise)
    try entry.addSet(reps: 8, weight: 135, weightUnit: .pounds)

    #expect(throws: WorkoutModelError.exerciseClassificationInUse) {
      try store.updateExercise(
        exercise,
        name: "Barbell Bench Press",
        loadMode: .bodyweight,
        repetitionMode: .standard
      )
    }
    #expect(exercise.name == "Bench Press")

    try store.updateExercise(
      exercise,
      name: "Barbell Bench Press",
      loadMode: .externalResistance,
      repetitionMode: .standard
    )
    #expect(exercise.name == "Barbell Bench Press")
  }

  @Test
  func explicitlyArchivingUnusedExerciseDoesNotDeleteIt() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let store = TrainingDataStore(modelContext: context)
    let exercise = try store.createExercise(
      name: "Cable Fly",
      loadMode: .externalResistance
    )
    try context.save()

    try store.archive(exercise)
    try context.save()

    #expect(exercise.isArchived)
    #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
  }

  @Test
  func removingUsedExerciseArchivesWithoutDeletingHistory() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let store = TrainingDataStore(modelContext: context)
    let exercise = try store.createExercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try store.startWorkout()
    let workoutEntry = try workout.addExercise(exercise)
    try workoutEntry.addSet(reps: 8, weight: 135, weightUnit: .pounds)
    try context.save()

    try store.remove(exercise)
    try context.save()

    #expect(exercise.isArchived)
    #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<ExerciseSet>()) == 1)
  }

  @Test
  func deletingUsedExerciseRequiresExplicitAssociatedDataRemoval() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let store = TrainingDataStore(modelContext: context)
    let exercise = try store.createExercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try store.startWorkout()
    let workoutEntry = try workout.addExercise(exercise)
    try workoutEntry.addSet(reps: 8, weight: 135, weightUnit: .pounds)
    let template = try store.createTemplate(name: "Push Day")
    try template.addExercise(exercise, plannedWorkingSetCount: 3)
    try context.save()

    #expect(
      store.deletionImpact(for: exercise)
        == ExerciseDeletionImpact(
          workoutEntryCount: 1,
          setCount: 1,
          templateEntryCount: 1
        )
    )
    #expect(throws: WorkoutModelError.exerciseHasAssociatedData) {
      try store.delete(exercise)
    }

    try store.delete(exercise, includingAssociatedData: true)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<ExerciseSet>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<TemplateExercise>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<WorkoutTemplate>()) == 1)
  }

  @Test
  func preparingAWorkoutCreatesItsPlannedDraftSets() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let store = TrainingDataStore(modelContext: context)
    let benchPress = try store.createExercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try store.startWorkout()
    let entry = try workout.addExercise(
      benchPress,
      plannedWorkingSetCount: 3
    )

    try store.prepareForEditing(workout)
    try context.save()

    #expect(entry.orderedSets.count == 3)
    #expect(entry.orderedSets.map(\.position) == [0, 1, 2])
    #expect(
      entry.orderedSets.allSatisfy {
        $0.reps == TrainingDefaults.repetitionCount
      }
    )
    #expect(entry.orderedSets.allSatisfy { $0.completedAt == nil })
  }

  @Test
  func preparingAWorkoutUsesTheExerciseStartingWorkingWeight() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let store = TrainingDataStore(modelContext: context)
    let benchPress = try store.createExercise(
      name: "Bench Press",
      loadMode: .externalResistance,
      startingWorkingWeight: Decimal(string: "62.5"),
      startingWorkingWeightUnit: .kilograms
    )
    let workout = try store.startWorkout()
    let entry = try workout.addExercise(
      benchPress,
      plannedWorkingSetCount: 4
    )

    try store.prepareForEditing(workout)

    #expect(entry.weightUnit == .kilograms)
    #expect(entry.orderedSets.count == 4)
    #expect(entry.orderedSets.allSatisfy { $0.weight == Decimal(string: "62.5") })
    #expect(entry.orderedSets.allSatisfy { $0.weightUnit == .kilograms })
  }

  @Test
  func addingAnExerciseToAnActiveWorkoutCreatesThreeWorkingSets() throws {
    let container = try makeContainer()
    let store = TrainingDataStore(modelContext: container.mainContext)
    let benchPress = try store.createExercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try store.startWorkout()

    let entry = try store.addExercise(benchPress, to: workout)

    #expect(entry.plannedWorkingSetCount == 3)
    #expect(entry.orderedSets.count == 3)
    #expect(entry.orderedSets.map(\.position) == [0, 1, 2])
    #expect(entry.orderedSets.allSatisfy { $0.kind == .working })
    #expect(
      entry.orderedSets.allSatisfy {
        $0.reps == TrainingDefaults.repetitionCount
      }
    )
    #expect(entry.orderedSets.allSatisfy { $0.completedAt == nil })
  }

  @Test
  func latestCompletedWorkingRepetitionsPrefillAllDraftSets() throws {
    let container = try makeContainer()
    let store = TrainingDataStore(modelContext: container.mainContext)
    let pushUp = try store.createExercise(
      name: "Push-up",
      loadMode: .bodyweight
    )

    let completedWorkout = try store.startWorkout(
      startedAt: Date(timeIntervalSince1970: 1_000)
    )
    let completedEntry = try store.addExercise(
      pushUp,
      to: completedWorkout
    )
    completedEntry.orderedSets[0].reps = 8
    completedEntry.orderedSets[1].reps = 9
    completedEntry.orderedSets[2].kind = .warmup
    completedEntry.orderedSets[2].reps = 20
    try store.setCompletion(true, for: completedEntry.orderedSets[0])
    try store.setCompletion(true, for: completedEntry.orderedSets[1])
    try store.setCompletion(true, for: completedEntry.orderedSets[2])
    try completedWorkout.complete(at: Date(timeIntervalSince1970: 2_000))

    let activeWorkout = try store.startWorkout(
      startedAt: Date(timeIntervalSince1970: 3_000)
    )
    let activeEntry = try store.addExercise(pushUp, to: activeWorkout)

    #expect(activeEntry.orderedSets.allSatisfy { $0.reps == 9 })
  }

  @Test
  func latestCompletedWorkingWeightOverridesTheExerciseStartingWeight() throws {
    let container = try makeContainer()
    let store = TrainingDataStore(modelContext: container.mainContext)
    let benchPress = try store.createExercise(
      name: "Bench Press",
      loadMode: .externalResistance,
      startingWorkingWeight: 45,
      startingWorkingWeightUnit: .kilograms
    )

    let firstWorkout = try store.startWorkout(
      startedAt: Date(timeIntervalSince1970: 1_000)
    )
    let firstEntry = try store.addExercise(benchPress, to: firstWorkout)
    for exerciseSet in firstEntry.orderedSets {
      exerciseSet.weight = 100
      exerciseSet.weightUnit = .pounds
      try store.setCompletion(true, for: exerciseSet)
    }
    try firstWorkout.complete(at: Date(timeIntervalSince1970: 2_000))

    let secondWorkout = try store.startWorkout(
      startedAt: Date(timeIntervalSince1970: 3_000)
    )
    let secondEntry = try store.addExercise(benchPress, to: secondWorkout)
    secondEntry.orderedSets[0].weight = 120
    secondEntry.orderedSets[1].weight = 125
    secondEntry.orderedSets[2].kind = .warmup
    secondEntry.orderedSets[2].weight = 40
    try store.setCompletion(true, for: secondEntry.orderedSets[0])
    try store.setCompletion(true, for: secondEntry.orderedSets[1])
    try store.setCompletion(true, for: secondEntry.orderedSets[2])
    try secondWorkout.complete(at: Date(timeIntervalSince1970: 4_000))

    let activeWorkout = try store.startWorkout(
      startedAt: Date(timeIntervalSince1970: 5_000)
    )
    let activeEntry = try store.addExercise(benchPress, to: activeWorkout)

    #expect(activeEntry.weightUnit == .pounds)
    #expect(activeEntry.orderedSets.allSatisfy { $0.weight == 125 })
    #expect(activeEntry.orderedSets.allSatisfy { $0.weightUnit == .pounds })
  }

  @Test
  func addingADraftSetDefaultsToWorkingAfterAWarmupSet() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let entry = try workout.addExercise(benchPress)
    let warmup = try entry.addDraftSet()
    warmup.kind = .warmup

    let newSet = try entry.addDraftSet()

    #expect(newSet.kind == .working)
  }

  @Test
  func changingAnActiveExerciseWeightUnitConvertsItsWeightedSets() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let entry = try workout.addExercise(benchPress)
    let emptySet = try entry.addDraftSet()
    let firstSet = try entry.addSet(
      reps: 8,
      weight: 100,
      weightUnit: .pounds
    )
    let secondSet = try entry.addSet(
      reps: 8,
      weight: 50,
      weightUnit: .pounds
    )

    entry.updateWeightUnit(to: .kilograms)

    #expect(entry.weightUnit == .kilograms)
    #expect(firstSet.weight == Decimal(string: "45.5"))
    #expect(secondSet.weight == Decimal(string: "22.5"))
    #expect(firstSet.weightUnit == .kilograms)
    #expect(secondSet.weightUnit == .kilograms)
    #expect(emptySet.weight == nil)
    #expect(emptySet.weightUnit == nil)
  }

  @Test
  func followingSetsCanInheritWeightWithoutChangingRepetitions() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let entry = try workout.addExercise(benchPress)
    let precedingSet = try entry.addSet(
      reps: 12,
      weight: 95,
      weightUnit: .pounds
    )
    let sourceSet = try entry.addSet(
      reps: 8,
      weight: 100,
      weightUnit: .pounds
    )
    let followingSet = try entry.addSet(
      reps: 6,
      weight: 105,
      weightUnit: .kilograms
    )

    entry.populateFollowingSetWeights(from: sourceSet)

    #expect(followingSet.reps == 6)
    #expect(followingSet.weight == 100)
    #expect(followingSet.weightUnit == .pounds)
    #expect(precedingSet.reps == 12)
    #expect(precedingSet.weight == 95)
  }

  @Test(arguments: [ExerciseOrigin.custom, .seeded])
  func startingWeightActionPersistsPreferenceAndFollowingSets(origin: ExerciseOrigin) throws {
    let container = try makeContainer()
    let context = container.mainContext
    let store = TrainingDataStore(modelContext: context)
    let exercise = try store.createExercise(
      name: "Starting Weight Test", loadMode: .externalResistance, origin: origin
    )
    let workout = try store.startWorkout()
    let entry = try store.addExercise(exercise, to: workout)
    let preceding = entry.orderedSets[0]
    preceding.weight = 20
    preceding.weightUnit = .pounds
    let source = entry.orderedSets[1]
    source.weight = Decimal(string: "42.5")
    source.weightUnit = .kilograms
    let following = entry.orderedSets[2]
    following.reps = 6
    let completedAt = following.completedAt

    try store.saveStartingWeight(from: source)

    let reloadedContext = ModelContext(container)
    let savedExercise = try #require(
      reloadedContext.fetch(FetchDescriptor<Exercise>()).first { $0.id == exercise.id }
    )
    let savedEntry = try #require(savedExercise.workoutExercises.first)
    #expect(savedExercise.startingWorkingWeight == Decimal(string: "42.5"))
    #expect(savedExercise.startingWorkingWeightUnit == .kilograms)
    #expect(savedEntry.orderedSets[0].weight == 20)
    #expect(savedEntry.orderedSets[0].weightUnit == .pounds)
    #expect(savedEntry.orderedSets[2].weight == Decimal(string: "42.5"))
    #expect(savedEntry.orderedSets[2].weightUnit == .kilograms)
    #expect(savedEntry.orderedSets[2].reps == 6)
    #expect(savedEntry.orderedSets[2].completedAt == completedAt)
    let appended = try entry.addDraftSet()
    #expect(appended.weight == Decimal(string: "93.5"))
    #expect(appended.weightUnit == .pounds)
  }

  @Test
  func startingWeightActionOnLastSetCanClearPreference() throws {
    let container = try makeContainer()
    let store = TrainingDataStore(modelContext: container.mainContext)
    let exercise = try store.createExercise(
      name: "Bodyweight Test", loadMode: .bodyweight, startingWorkingWeight: 20
    )
    let workout = try store.startWorkout()
    let entry = try store.addExercise(exercise, to: workout)
    let source = try #require(entry.orderedSets.last)
    source.weight = nil
    source.weightUnit = nil

    try store.saveStartingWeight(from: source)

    let saved = try #require(ModelContext(container).fetch(FetchDescriptor<Exercise>()).first)
    #expect(saved.startingWorkingWeight == nil)
    #expect(saved.startingWorkingWeightUnit == nil)
  }

  @Test
  func followingSetsExcludeTheSourceSetAndEverythingBeforeIt() throws {
    let benchPress = try Exercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let workout = try Workout()
    let entry = try workout.addExercise(benchPress)
    let firstSet = try entry.addSet(reps: 8, weight: 95, weightUnit: .pounds)
    let secondSet = try entry.addSet(reps: 8, weight: 100, weightUnit: .pounds)
    let thirdSet = try entry.addSet(reps: 8, weight: 105, weightUnit: .pounds)
    let otherEntry = try workout.addExercise(benchPress)
    let unrelatedSet = try otherEntry.addSet(reps: 5, weight: 135, weightUnit: .pounds)

    #expect(entry.followingSets(after: firstSet).map(\.id) == [secondSet.id, thirdSet.id])
    #expect(entry.followingSets(after: secondSet).map(\.id) == [thirdSet.id])
    #expect(entry.followingSets(after: thirdSet).isEmpty)
    #expect(entry.followingSets(after: unrelatedSet).isEmpty)
  }

  @Test
  func activeWorkoutAllowsDuplicateExercisesAndNormalizesReordering() throws {
    let container = try makeContainer()
    let store = TrainingDataStore(modelContext: container.mainContext)
    let benchPress = try store.createExercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let squat = try store.createExercise(
      name: "Squat",
      loadMode: .externalResistance
    )
    let workout = try store.startWorkout()
    let firstBench = try store.addExercise(benchPress, to: workout)
    let squatEntry = try store.addExercise(squat, to: workout)
    let secondBench = try store.addExercise(benchPress, to: workout)

    try store.reorderExercises(
      in: workout,
      to: [secondBench, firstBench, squatEntry]
    )

    #expect(
      workout.orderedExercises.map(\.id)
        == [secondBench.id, firstBench.id, squatEntry.id]
    )
    #expect(workout.orderedExercises.map(\.position) == [0, 1, 2])
  }

  @Test
  func removingAWorkoutExerciseCascadesSetsAndKeepsRemainingRowsValid() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let store = TrainingDataStore(modelContext: context)
    let benchPress = try store.createExercise(
      name: "Bench Press",
      loadMode: .externalResistance
    )
    let squat = try store.createExercise(
      name: "Squat",
      loadMode: .externalResistance
    )
    let workout = try store.startWorkout()
    let benchEntry = try store.addExercise(benchPress, to: workout)
    let squatEntry = try store.addExercise(squat, to: workout)
    try context.save()

    try store.remove(benchEntry, from: workout)
    try context.save()

    #expect(workout.orderedExercises.map(\.id) == [squatEntry.id])
    #expect(workout.orderedExercises.map(\.position) == [0])
    #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<ExerciseSet>()) == 3)
  }

  @Test
  func anExerciseAlwaysKeepsAtLeastOneSet() throws {
    let pushUp = try Exercise(name: "Push-up", loadMode: .bodyweight)
    let workout = try Workout()
    let entry = try workout.addExercise(pushUp)
    let firstSet = try entry.addDraftSet()

    #expect(throws: WorkoutModelError.cannotRemoveLastSet) {
      try entry.removeSet(firstSet)
    }

    let secondSet = try entry.addDraftSet()
    try entry.removeSet(firstSet)

    #expect(entry.orderedSets.count == 1)
    #expect(entry.orderedSets.first === secondSet)
    #expect(entry.orderedSets.first?.position == 0)
  }

  private func makeContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(
      schema: BurthenSchema.schema,
      isStoredInMemoryOnly: true
    )
    return try ModelContainer(
      for: BurthenSchema.schema,
      configurations: [configuration]
    )
  }
}
