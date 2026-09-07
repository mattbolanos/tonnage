//
//  Exercise.swift
//  Burthen
//


import Foundation
import SwiftData

@Model
final class Exercise {
  var id: UUID = UUID()
  var name: String = ""
  var loadMode: ExerciseLoadMode = ExerciseLoadMode.externalResistance
  var repetitionMode: ExerciseRepetitionMode = ExerciseRepetitionMode.standard
  var startingWorkingWeight: Decimal?
  var startingWorkingWeightUnit: WeightUnit?
  var origin: ExerciseOrigin = ExerciseOrigin.custom
  var isArchived = false
  var createdAt: Date = Date.now
  var updatedAt: Date = Date.now

  @Relationship(deleteRule: .deny, inverse: \WorkoutExercise.exercise)
  var workoutExercises: [WorkoutExercise] = []

  @Relationship(deleteRule: .deny, inverse: \TemplateExercise.exercise)
  var templateExercises: [TemplateExercise] = []

  init(
    id: UUID = UUID(),
    name: String,
    loadMode: ExerciseLoadMode,
    repetitionMode: ExerciseRepetitionMode = .standard,
    startingWorkingWeight: Decimal? = nil,
    startingWorkingWeightUnit: WeightUnit = .pounds,
    origin: ExerciseOrigin = .custom,
    isArchived: Bool = false,
    createdAt: Date = .now,
    updatedAt: Date = .now
  ) throws {
    let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedName.isEmpty else { throw WorkoutModelError.emptyName }
    try Self.validateStartingWorkingWeight(startingWorkingWeight)

    self.id = id
    self.name = normalizedName
    self.loadMode = loadMode
    self.repetitionMode = repetitionMode
    self.startingWorkingWeight = startingWorkingWeight
    self.startingWorkingWeightUnit = startingWorkingWeight == nil
      ? nil
      : startingWorkingWeightUnit
    self.origin = origin
    self.isArchived = isArchived
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  var hasHistoricalSets: Bool {
    workoutExercises.contains { !$0.exerciseSets.isEmpty }
  }

  func rename(to newName: String, at date: Date = .now) throws {
    guard origin == .custom else { throw WorkoutModelError.seededExerciseIsReadOnly }

    let normalizedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedName.isEmpty else { throw WorkoutModelError.emptyName }

    name = normalizedName
    updatedAt = date
  }

  func updateClassification(
    loadMode: ExerciseLoadMode,
    repetitionMode: ExerciseRepetitionMode,
    at date: Date = .now
  ) throws {
    guard origin == .custom else { throw WorkoutModelError.seededExerciseIsReadOnly }
    guard !hasHistoricalSets else { throw WorkoutModelError.exerciseClassificationInUse }

    self.loadMode = loadMode
    self.repetitionMode = repetitionMode
    updatedAt = date
  }

  func updateStartingWorkingWeight(
    _ weight: Decimal?,
    unit: WeightUnit = .pounds,
    at date: Date = .now
  ) throws {
    // Starting weight is a personal preference, including for built-in exercises.
    try Self.validateStartingWorkingWeight(weight)

    startingWorkingWeight = weight
    startingWorkingWeightUnit = weight == nil ? nil : unit
    updatedAt = date
  }

  static func validateStartingWorkingWeight(_ weight: Decimal?) throws {
    guard let weight else { return }
    guard weight > 0 else { throw WorkoutModelError.invalidWeight }
    guard weight.hasAtMostOneFractionalDigit else {
      throw WorkoutModelError.invalidWeightPrecision
    }
  }

  func archive(at date: Date = .now) throws {
    guard origin == .custom else { throw WorkoutModelError.seededExerciseIsReadOnly }
    isArchived = true
    updatedAt = date
  }

  func restore(at date: Date = .now) {
    isArchived = false
    updatedAt = date
  }
}
