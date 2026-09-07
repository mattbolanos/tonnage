//
//  TrainingDataStore.swift
//  Burthen
//


import Foundation
import SwiftData

struct ExerciseDeletionImpact: Equatable {
  let workoutEntryCount: Int
  let setCount: Int
  let templateEntryCount: Int

  var hasAssociatedData: Bool {
    workoutEntryCount > 0 || setCount > 0 || templateEntryCount > 0
  }
}

@MainActor
struct TrainingDataStore {
  let modelContext: ModelContext

  func startWorkout(
    name: String? = nil,
    notes: String? = nil,
    startedAt: Date = .now,
    timeZoneIdentifier: String = TimeZone.current.identifier
  ) throws -> Workout {
    try ensureNoActiveWorkout()

    let workout = try Workout(
      name: name,
      notes: notes,
      startedAt: startedAt,
      timeZoneIdentifier: timeZoneIdentifier
    )
    modelContext.insert(workout)
    return workout
  }

  func startWorkout(
    from template: WorkoutTemplate,
    startedAt: Date = .now,
    timeZoneIdentifier: String = TimeZone.current.identifier
  ) throws -> Workout {
    try ensureNoActiveWorkout()

    let workout = try template.makeWorkout(
      startedAt: startedAt,
      timeZoneIdentifier: timeZoneIdentifier,
      createdAt: startedAt
    )
    modelContext.insert(workout)
    return workout
  }

  func createExercise(
    name: String,
    loadMode: ExerciseLoadMode,
    repetitionMode: ExerciseRepetitionMode = .standard,
    startingWorkingWeight: Decimal? = nil,
    startingWorkingWeightUnit: WeightUnit = .pounds,
    origin: ExerciseOrigin = .custom
  ) throws -> Exercise {
    let normalizedName = try validatedName(name)
    let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
    guard !exercises.contains(where: { !$0.isArchived && namesMatch($0.name, normalizedName) }) else {
      throw WorkoutModelError.duplicateExerciseName
    }

    let exercise = try Exercise(
      name: normalizedName,
      loadMode: loadMode,
      repetitionMode: repetitionMode,
      startingWorkingWeight: startingWorkingWeight,
      startingWorkingWeightUnit: startingWorkingWeightUnit,
      origin: origin
    )
    modelContext.insert(exercise)
    return exercise
  }

  func updateExercise(
    _ exercise: Exercise,
    name: String,
    loadMode: ExerciseLoadMode,
    repetitionMode: ExerciseRepetitionMode,
    at date: Date = .now
  ) throws {
    try updateExercise(
      exercise,
      name: name,
      loadMode: loadMode,
      repetitionMode: repetitionMode,
      startingWorkingWeight: exercise.startingWorkingWeight,
      startingWorkingWeightUnit: exercise.startingWorkingWeightUnit ?? .pounds,
      at: date
    )
  }

  func updateExercise(
    _ exercise: Exercise,
    name: String,
    loadMode: ExerciseLoadMode,
    repetitionMode: ExerciseRepetitionMode,
    startingWorkingWeight: Decimal?,
    startingWorkingWeightUnit: WeightUnit,
    at date: Date = .now
  ) throws {
    guard exercise.origin == .custom else {
      throw WorkoutModelError.seededExerciseIsReadOnly
    }

    let normalizedName = try validatedName(name)
    let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
    guard !exercises.contains(where: {
      $0 !== exercise
        && !$0.isArchived
        && !exercise.isArchived
        && namesMatch($0.name, normalizedName)
    }) else {
      throw WorkoutModelError.duplicateExerciseName
    }

    let classificationChanged = exercise.loadMode != loadMode
      || exercise.repetitionMode != repetitionMode
    guard !classificationChanged || !exercise.hasHistoricalSets else {
      throw WorkoutModelError.exerciseClassificationInUse
    }
    try Exercise.validateStartingWorkingWeight(startingWorkingWeight)

    if exercise.name != normalizedName {
      try exercise.rename(to: normalizedName, at: date)
    }
    if classificationChanged {
      try exercise.updateClassification(
        loadMode: loadMode,
        repetitionMode: repetitionMode,
        at: date
      )
    }
    if exercise.startingWorkingWeight != startingWorkingWeight
      || exercise.startingWorkingWeightUnit
        != (startingWorkingWeight == nil ? nil : startingWorkingWeightUnit) {
      try exercise.updateStartingWorkingWeight(
        startingWorkingWeight,
        unit: startingWorkingWeightUnit,
        at: date
      )
    }
  }

  /// Commits the exercise preference and subsequent set weights together using
  /// the existing context. Restore only this action's changes if saving fails.
  func saveStartingWeight(from sourceSet: ExerciseSet, at date: Date = .now) throws {
    guard let entry = sourceSet.workoutExercise,
          let exercise = entry.exercise else {
      throw WorkoutModelError.missingExercise
    }
    try Exercise.validateStartingWorkingWeight(sourceSet.weight)
    if sourceSet.weight != nil && sourceSet.weightUnit == nil {
      throw WorkoutModelError.missingWeightUnit
    }

    let previousWeight = exercise.startingWorkingWeight
    let previousUnit = exercise.startingWorkingWeightUnit
    let previousUpdatedAt = exercise.updatedAt
    let previousWorkoutUpdatedAt = entry.workout?.updatedAt
    let followingWeights = entry.followingSets(after: sourceSet).map {
      (set: $0, weight: $0.weight, unit: $0.weightUnit)
    }

    do {
      try exercise.updateStartingWorkingWeight(
        sourceSet.weight, unit: sourceSet.weightUnit ?? entry.weightUnit, at: date
      )
      entry.populateFollowingSetWeights(from: sourceSet)
      entry.workout?.updatedAt = date
      try modelContext.save()
    } catch {
      exercise.startingWorkingWeight = previousWeight
      exercise.startingWorkingWeightUnit = previousUnit
      exercise.updatedAt = previousUpdatedAt
      if let previousWorkoutUpdatedAt {
        entry.workout?.updatedAt = previousWorkoutUpdatedAt
      }
      for previous in followingWeights {
        previous.set.weight = previous.weight
        previous.set.weightUnit = previous.unit
      }
      throw error
    }
  }

  func createTemplate(
    name: String,
    notes: String? = nil,
    exercises: [TemplateExercisePlan] = []
  ) throws -> WorkoutTemplate {
    let normalizedName = try validatedName(name)
    let templates = try modelContext.fetch(FetchDescriptor<WorkoutTemplate>())
    guard !templates.contains(where: { !$0.isArchived && namesMatch($0.name, normalizedName) }) else {
      throw WorkoutModelError.duplicateTemplateName
    }
    try validate(exercises)

    let template = try WorkoutTemplate(name: normalizedName, notes: notes)
    modelContext.insert(template)
    try append(exercises, to: template)
    return template
  }

  func updateTemplate(
    _ template: WorkoutTemplate,
    name: String,
    notes: String?,
    exercises: [TemplateExercisePlan],
    at date: Date = .now
  ) throws {
    let normalizedName = try validatedName(name)
    let templates = try modelContext.fetch(FetchDescriptor<WorkoutTemplate>())
    guard !templates.contains(where: {
      $0 !== template
        && !$0.isArchived
        && !template.isArchived
        && namesMatch($0.name, normalizedName)
    }) else {
      throw WorkoutModelError.duplicateTemplateName
    }
    try validate(exercises)

    try template.updateDetails(name: normalizedName, notes: notes, at: date)

    let previousExercises = template.templateExercises
    template.templateExercises.removeAll()
    for templateExercise in previousExercises {
      modelContext.delete(templateExercise)
    }
    try append(exercises, to: template, at: date)
  }

  func archive(_ template: WorkoutTemplate) {
    template.archive()
  }

  func restore(_ template: WorkoutTemplate) throws {
    let templates = try modelContext.fetch(FetchDescriptor<WorkoutTemplate>())
    guard !templates.contains(where: {
      $0 !== template && !$0.isArchived && namesMatch($0.name, template.name)
    }) else {
      throw WorkoutModelError.duplicateTemplateName
    }

    template.restore()
  }

  func discard(_ workout: Workout) throws {
    guard workout.status == .inProgress else {
      throw WorkoutModelError.workoutIsNotInProgress
    }
    modelContext.delete(workout)
  }

  func prepareForEditing(_ workout: Workout) throws {
    try requireInProgress(workout)

    for workoutExercise in workout.orderedExercises
    where workoutExercise.exerciseSets.isEmpty {
      let setCount = max(
        workoutExercise.plannedWorkingSetCount ?? TrainingDefaults.workingSetCount,
        1
      )
      try addDraftSets(count: setCount, to: workoutExercise)
    }
  }

  @discardableResult
  func addExercise(
    _ exercise: Exercise,
    to workout: Workout,
    at date: Date = .now
  ) throws -> WorkoutExercise {
    try requireInProgress(workout)

    let workoutExercise = try workout.addExercise(
      exercise,
      plannedWorkingSetCount: TrainingDefaults.workingSetCount,
      at: date
    )
    modelContext.insert(workoutExercise)
    try addDraftSets(
      count: TrainingDefaults.workingSetCount,
      to: workoutExercise
    )
    return workoutExercise
  }

  @discardableResult
  func addSet(
    to workoutExercise: WorkoutExercise,
    at date: Date = .now
  ) throws -> ExerciseSet {
    let workout = try activeWorkout(for: workoutExercise)
    let exerciseSet = try workoutExercise.addDraftSet()
    modelContext.insert(exerciseSet)
    workout.updatedAt = date
    return exerciseSet
  }

  func remove(
    _ exerciseSet: ExerciseSet,
    from workoutExercise: WorkoutExercise,
    at date: Date = .now
  ) throws {
    let workout = try activeWorkout(for: workoutExercise)
    try workoutExercise.removeSet(exerciseSet)
    modelContext.delete(exerciseSet)
    workout.updatedAt = date
  }

  func updateWeightUnit(
    for workoutExercise: WorkoutExercise,
    to weightUnit: WeightUnit,
    at date: Date = .now
  ) throws {
    let workout = try activeWorkout(for: workoutExercise)
    guard workoutExercise.requiresWeightUnitUpdate(to: weightUnit) else { return }
    workoutExercise.updateWeightUnit(to: weightUnit)
    workout.updatedAt = date
  }

  func setCompletion(
    _ isCompleted: Bool,
    for exerciseSet: ExerciseSet,
    at date: Date = .now
  ) throws {
    guard let workoutExercise = exerciseSet.workoutExercise else {
      throw WorkoutModelError.missingExercise
    }
    let workout = try activeWorkout(for: workoutExercise)

    if isCompleted {
      try exerciseSet.validate()
      exerciseSet.completedAt = date
    } else {
      exerciseSet.completedAt = nil
    }
    workout.updatedAt = date
  }

  func remove(
    _ workoutExercise: WorkoutExercise,
    from workout: Workout,
    at date: Date = .now
  ) throws {
    try requireInProgress(workout)
    workout.removeExercise(workoutExercise, at: date)
    modelContext.delete(workoutExercise)
  }

  func reorderExercises(
    in workout: Workout,
    to orderedExercises: [WorkoutExercise],
    at date: Date = .now
  ) throws {
    try requireInProgress(workout)
    workout.updateExerciseOrder(orderedExercises, at: date)
  }

  func remove(_ template: WorkoutTemplate) {
    if template.canBePermanentlyDeleted {
      modelContext.delete(template)
    } else {
      template.archive()
    }
  }

  func remove(_ exercise: Exercise) throws {
    guard exercise.origin == .custom else {
      throw WorkoutModelError.seededExerciseIsReadOnly
    }

    if exercise.workoutExercises.isEmpty && exercise.templateExercises.isEmpty {
      modelContext.delete(exercise)
    } else {
      try archive(exercise)
    }
  }

  func archive(_ exercise: Exercise) throws {
    guard exercise.origin == .custom else {
      throw WorkoutModelError.seededExerciseIsReadOnly
    }

    try exercise.archive()
  }

  func restore(_ exercise: Exercise) throws {
    guard exercise.origin == .custom else {
      throw WorkoutModelError.seededExerciseIsReadOnly
    }

    let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
    guard !exercises.contains(where: {
      $0 !== exercise && !$0.isArchived && namesMatch($0.name, exercise.name)
    }) else {
      throw WorkoutModelError.duplicateExerciseName
    }

    exercise.restore()
  }

  func deletionImpact(for exercise: Exercise) -> ExerciseDeletionImpact {
    ExerciseDeletionImpact(
      workoutEntryCount: exercise.workoutExercises.count,
      setCount: exercise.workoutExercises.reduce(0) { count, workoutExercise in
        count + workoutExercise.exerciseSets.count
      },
      templateEntryCount: exercise.templateExercises.count
    )
  }

  func delete(
    _ exercise: Exercise,
    includingAssociatedData: Bool = false
  ) throws {
    guard exercise.origin == .custom else {
      throw WorkoutModelError.seededExerciseIsReadOnly
    }

    let impact = deletionImpact(for: exercise)
    guard includingAssociatedData || !impact.hasAssociatedData else {
      throw WorkoutModelError.exerciseHasAssociatedData
    }

    let workoutEntries = exercise.workoutExercises
    let templateEntries = exercise.templateExercises

    exercise.workoutExercises.removeAll()
    exercise.templateExercises.removeAll()

    for workoutEntry in workoutEntries {
      modelContext.delete(workoutEntry)
    }
    for templateEntry in templateEntries {
      modelContext.delete(templateEntry)
    }

    modelContext.delete(exercise)
  }

  private func ensureNoActiveWorkout() throws {
    let workouts = try modelContext.fetch(FetchDescriptor<Workout>())
    guard !workouts.contains(where: { $0.status == .inProgress }) else {
      throw WorkoutModelError.activeWorkoutExists
    }
  }

  private func requireInProgress(_ workout: Workout) throws {
    guard workout.status == .inProgress else {
      throw WorkoutModelError.workoutIsNotInProgress
    }
  }

  private func activeWorkout(for workoutExercise: WorkoutExercise) throws -> Workout {
    guard let workout = workoutExercise.workout else {
      throw WorkoutModelError.missingExercise
    }
    try requireInProgress(workout)
    return workout
  }

  private func addDraftSets(
    count: Int,
    to workoutExercise: WorkoutExercise
  ) throws {
    guard let exercise = workoutExercise.exercise else {
      throw WorkoutModelError.missingExercise
    }

    let completedSets = completedSets(for: exercise)
    let startingWeight = preferredStartingWeight(
      for: exercise,
      completedSets: completedSets
    )
    let startingRepetitions = preferredStartingRepetitions(
      completedSets: completedSets
    )

    if let startingWeight {
      workoutExercise.preferredWeightUnit = startingWeight.unit
    }

    for _ in 0..<count {
      let exerciseSet = try workoutExercise.addDraftSet(
        defaultRepetitions: startingRepetitions
      )
      if exerciseSet.weight == nil, let startingWeight {
        exerciseSet.weight = startingWeight.value
        exerciseSet.weightUnit = startingWeight.unit
      }
      modelContext.insert(exerciseSet)
    }
  }

  private func preferredStartingWeight(
    for exercise: Exercise,
    completedSets: [ExerciseSet]
  ) -> (value: Decimal, unit: WeightUnit)? {
    if !completedSets.isEmpty {
      let completedWorkingSets = completedSets.filter { exerciseSet in
        exerciseSet.kind == .working
          && exerciseSet.weight != nil
          && exerciseSet.weightUnit != nil
      }
      guard
        let exerciseSet = completedWorkingSets.max(by: isEarlierCompletedSet),
        let weight = exerciseSet.weight,
        let unit = exerciseSet.weightUnit
      else { return nil }

      return (weight, unit)
    }

    guard
      let weight = exercise.startingWorkingWeight,
      let unit = exercise.startingWorkingWeightUnit
    else { return nil }

    return (weight, unit)
  }

  private func preferredStartingRepetitions(
    completedSets: [ExerciseSet]
  ) -> Int {
    let latestWorkingSet = completedSets
      .filter { $0.kind == .working }
      .max(by: isEarlierCompletedSet)

    return max(
      latestWorkingSet?.reps ?? TrainingDefaults.repetitionCount,
      1
    )
  }

  private func completedSets(for exercise: Exercise) -> [ExerciseSet] {
    exercise.workoutExercises.flatMap { workoutExercise in
      guard workoutExercise.workout?.status == .completed else {
        return [ExerciseSet]()
      }
      return workoutExercise.exerciseSets.filter(\.isCompleted)
    }
  }

  private func isEarlierCompletedSet(
    _ lhs: ExerciseSet,
    _ rhs: ExerciseSet
  ) -> Bool {
    guard
      let lhsWorkout = lhs.workoutExercise?.workout,
      let rhsWorkout = rhs.workoutExercise?.workout
    else { return lhs.id.uuidString < rhs.id.uuidString }

    let lhsWorkoutDate = lhsWorkout.endedAt ?? lhsWorkout.updatedAt
    let rhsWorkoutDate = rhsWorkout.endedAt ?? rhsWorkout.updatedAt
    if lhsWorkoutDate != rhsWorkoutDate {
      return lhsWorkoutDate < rhsWorkoutDate
    }

    let lhsSetDate = lhs.completedAt ?? lhsWorkoutDate
    let rhsSetDate = rhs.completedAt ?? rhsWorkoutDate
    if lhsSetDate != rhsSetDate {
      return lhsSetDate < rhsSetDate
    }

    if lhs.position != rhs.position {
      return lhs.position < rhs.position
    }

    return lhs.id.uuidString < rhs.id.uuidString
  }

  private func validate(_ exercises: [TemplateExercisePlan]) throws {
    var exerciseIDs = Set<UUID>()

    for plan in exercises {
      guard !plan.exercise.isArchived else {
        throw WorkoutModelError.exerciseIsArchived
      }
      if let plannedWorkingSetCount = plan.plannedWorkingSetCount,
         plannedWorkingSetCount <= 0 {
        throw WorkoutModelError.invalidPlannedSetCount
      }
      guard exerciseIDs.insert(plan.exercise.id).inserted else {
        throw WorkoutModelError.duplicateExerciseInTemplate
      }
    }
  }

  private func append(
    _ exercises: [TemplateExercisePlan],
    to template: WorkoutTemplate,
    at date: Date = .now
  ) throws {
    for plan in exercises {
      let templateExercise = try template.addExercise(
        plan.exercise,
        plannedWorkingSetCount: plan.plannedWorkingSetCount,
        at: date
      )
      modelContext.insert(templateExercise)
    }
  }

  private func validatedName(_ name: String) throws -> String {
    let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedName.isEmpty else { throw WorkoutModelError.emptyName }
    return normalizedName
  }

  private func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
    lhs.compare(
      rhs,
      options: [.caseInsensitive, .diacriticInsensitive],
      range: nil,
      locale: .current
    ) == .orderedSame
  }
}
