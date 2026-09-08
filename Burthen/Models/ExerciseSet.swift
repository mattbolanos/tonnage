//
//  ExerciseSet.swift
//  Burthen
//


import Foundation
import SwiftData

@Model
final class ExerciseSet {
  var id: UUID = UUID()
  var position = 0
  var kind: ExerciseSetKind = ExerciseSetKind.working
  var reps = 1
  var weight: Decimal?
  var weightUnit: WeightUnit?
  var completedAt: Date?
  var workoutExercise: WorkoutExercise?

  init(
    id: UUID = UUID(),
    position: Int,
    kind: ExerciseSetKind = .working,
    reps: Int,
    weight: Decimal? = nil,
    weightUnit: WeightUnit? = nil,
    completedAt: Date? = .now,
    workoutExercise: WorkoutExercise? = nil
  ) {
    self.id = id
    self.position = position
    self.kind = kind
    self.reps = reps
    self.weight = weight
    self.weightUnit = weightUnit
    self.completedAt = completedAt
    self.workoutExercise = workoutExercise
  }

  var repetitionMode: ExerciseRepetitionMode {
    workoutExercise?.exercise?.repetitionMode ?? .standard
  }

  var volumeLoad: VolumeLoad? {
    guard isCompleted else { return nil }

    return VolumeLoad.forSet(
      kind: kind,
      repetitions: reps,
      repetitionMode: repetitionMode,
      weight: weight,
      unit: weightUnit
    )
  }

  var isCompleted: Bool {
    completedAt != nil
  }

  func validate() throws {
    guard let exercise = workoutExercise?.exercise else {
      throw WorkoutModelError.missingExercise
    }
    try validate(for: exercise)
  }

  func validate(for exercise: Exercise) throws {
    guard position >= 0 else { throw WorkoutModelError.invalidPosition }
    guard reps > 0 else { throw WorkoutModelError.invalidReps }

    switch (weight, weightUnit) {
    case (nil, nil):
      break
    case (.some(let weight), .some):
      guard weight >= 0 else { throw WorkoutModelError.invalidWeight }
      guard weight.hasAtMostOneFractionalDigit else {
        throw WorkoutModelError.invalidWeightPrecision
      }
    case (.some, nil):
      throw WorkoutModelError.missingWeightUnit
    case (nil, .some):
      throw WorkoutModelError.unexpectedWeightUnit
    }

    if exercise.loadMode == .externalResistance && weight == nil {
      throw WorkoutModelError.missingWeight
    }
  }
}
