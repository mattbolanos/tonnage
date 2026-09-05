//
//  WorkoutExercise.swift
//  Burthen
//


import Foundation
import SwiftData

@Model
final class WorkoutExercise {
  var id: UUID = UUID()
  var position = 0
  var plannedWorkingSetCount: Int?
  var preferredWeightUnit: WeightUnit?
  var workout: Workout?
  var exercise: Exercise?

  @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workoutExercise)
  var exerciseSets: [ExerciseSet] = []

  init(
    id: UUID = UUID(),
    position: Int,
    plannedWorkingSetCount: Int? = nil,
    weightUnit: WeightUnit = .pounds,
    workout: Workout? = nil,
    exercise: Exercise? = nil
  ) throws {
    guard position >= 0 else { throw WorkoutModelError.invalidPosition }
    if let plannedWorkingSetCount, plannedWorkingSetCount <= 0 {
      throw WorkoutModelError.invalidPlannedSetCount
    }

    self.id = id
    self.position = position
    self.plannedWorkingSetCount = plannedWorkingSetCount
    self.preferredWeightUnit = weightUnit
    self.workout = workout
    self.exercise = exercise
  }

  var orderedSets: [ExerciseSet] {
    exerciseSets.sorted { lhs, rhs in
      if lhs.position == rhs.position {
        lhs.id.uuidString < rhs.id.uuidString
      } else {
        lhs.position < rhs.position
      }
    }
  }

  var weightUnit: WeightUnit {
    preferredWeightUnit
      ?? orderedSets.compactMap(\.weightUnit).first
      ?? .pounds
  }

  var volumeLoad: VolumeLoad? {
    volumeLoad(in: weightUnit)
  }

  var workingSets: [ExerciseSet] {
    orderedSets.filter { $0.kind == .working }
  }

  var completedWorkingSetCount: Int {
    workingSets.count { $0.isCompleted }
  }

  var isCompleted: Bool {
    !workingSets.isEmpty && completedWorkingSetCount == workingSets.count
  }

  func addSet(
    kind: ExerciseSetKind = .working,
    reps: Int,
    weight: Decimal? = nil,
    weightUnit: WeightUnit? = nil,
    completedAt: Date? = .now
  ) throws -> ExerciseSet {
    guard let exercise else { throw WorkoutModelError.missingExercise }

    let exerciseSet = ExerciseSet(
      position: nextSetPosition,
      kind: kind,
      reps: reps,
      weight: weight,
      weightUnit: weightUnit,
      completedAt: completedAt,
      workoutExercise: nil
    )
    try exerciseSet.validate(for: exercise)
    exerciseSet.workoutExercise = self
    if !exerciseSets.contains(where: { $0 === exerciseSet }) {
      exerciseSets.append(exerciseSet)
    }
    if exerciseSets.count == 1, let weightUnit {
      preferredWeightUnit = weightUnit
    }

    return exerciseSet
  }

  @discardableResult
  func addDraftSet(
    defaultRepetitions: Int = TrainingDefaults.repetitionCount
  ) throws -> ExerciseSet {
    guard exercise != nil else { throw WorkoutModelError.missingExercise }

    let previousSet = orderedSets.last
    let previousWeight = previousSet.flatMap { exerciseSet -> Decimal? in
      guard let weight = exerciseSet.weight else { return nil }
      let sourceUnit = exerciseSet.weightUnit ?? weightUnit
      return sourceUnit.convert(weight, to: weightUnit).roundedToNearestHalf
    }
    let exerciseSet = ExerciseSet(
      position: nextSetPosition,
      kind: .working,
      reps: max(previousSet?.reps ?? defaultRepetitions, 1),
      weight: previousWeight,
      weightUnit: previousWeight == nil ? nil : weightUnit,
      completedAt: nil,
      workoutExercise: self
    )
    if !exerciseSets.contains(where: { $0 === exerciseSet }) {
      exerciseSets.append(exerciseSet)
    }

    return exerciseSet
  }

  func updateWeightUnit(to newUnit: WeightUnit) {
    guard requiresWeightUnitUpdate(to: newUnit) else { return }
    let fallbackUnit = weightUnit

    for exerciseSet in exerciseSets {
      guard let weight = exerciseSet.weight else {
        exerciseSet.weightUnit = nil
        continue
      }

      let sourceUnit = exerciseSet.weightUnit ?? fallbackUnit
      exerciseSet.weight = sourceUnit
        .convert(weight, to: newUnit)
        .roundedToNearestHalf
      exerciseSet.weightUnit = newUnit
    }

    preferredWeightUnit = newUnit
  }

  /// The sets ordered after `sourceSet`, or an empty array when `sourceSet`
  /// is the last set or does not belong to this exercise.
  func followingSets(after sourceSet: ExerciseSet) -> [ExerciseSet] {
    let sets = orderedSets
    guard let sourceIndex = sets.firstIndex(where: { $0.id == sourceSet.id }) else {
      return []
    }

    return Array(sets.dropFirst(sourceIndex + 1))
  }

  func populateFollowingSetWeights(from sourceSet: ExerciseSet) {
    for exerciseSet in followingSets(after: sourceSet) {
      exerciseSet.weight = sourceSet.weight
      exerciseSet.weightUnit = sourceSet.weightUnit
    }
  }

  func requiresWeightUnitUpdate(to newUnit: WeightUnit) -> Bool {
    preferredWeightUnit != newUnit
      || exerciseSets.contains { exerciseSet in
        exerciseSet.weight == nil
          ? exerciseSet.weightUnit != nil
          : exerciseSet.weightUnit != newUnit
      }
  }

  func removeSet(_ exerciseSet: ExerciseSet) throws {
    guard exerciseSets.contains(where: { $0 === exerciseSet }) else { return }
    guard exerciseSets.count > 1 else {
      throw WorkoutModelError.cannotRemoveLastSet
    }

    exerciseSets.removeAll { $0 === exerciseSet }
    exerciseSet.workoutExercise = nil
    normalizeSetPositions()
  }

  func volumeLoad(in unit: WeightUnit) -> VolumeLoad? {
    let values = exerciseSets.compactMap { $0.volumeLoad?.converted(to: unit).value }
    guard !values.isEmpty else { return nil }

    return VolumeLoad(value: values.reduce(Decimal.zero, +), unit: unit)
  }

  func validate() throws {
    guard position >= 0 else { throw WorkoutModelError.invalidPosition }
    if let plannedWorkingSetCount, plannedWorkingSetCount <= 0 {
      throw WorkoutModelError.invalidPlannedSetCount
    }
    guard exercise != nil else { throw WorkoutModelError.missingExercise }

    for exerciseSet in exerciseSets {
      try exerciseSet.validate()
    }
  }

  private var nextSetPosition: Int {
    (exerciseSets.map(\.position).max() ?? -1) + 1
  }

  private func normalizeSetPositions() {
    for (position, exerciseSet) in orderedSets.enumerated() {
      exerciseSet.position = position
    }
  }
}

private extension Decimal {
  var roundedToNearestHalf: Decimal {
    var source = self * 2
    var rounded = Decimal()
    NSDecimalRound(&rounded, &source, 0, .plain)
    return rounded / 2
  }
}
