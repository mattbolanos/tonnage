//
//  TrainingTypes.swift
//  Burthen
//


import Foundation

enum WorkoutStatus: String, Codable, CaseIterable {
  case inProgress
  case completed
}

enum ExerciseLoadMode: String, Codable, CaseIterable {
  case externalResistance
  case bodyweight
}

enum ExerciseRepetitionMode: String, Codable, CaseIterable {
  case standard
  case perSide

  var repetitionsLabel: String {
    self == .perSide ? "Repetitions per side" : "Repetitions"
  }

  func description(for repetitions: Int, abbreviated: Bool = false) -> String {
    let unit = abbreviated ? "reps" : "repetitions"
    return self == .perSide
      ? "\(repetitions) \(unit) per side"
      : "\(repetitions) \(unit)"
  }
}

enum ExerciseOrigin: String, Codable, CaseIterable {
  case seeded
  case custom
}

enum ExerciseSetKind: String, Codable, CaseIterable {
  case working
  case warmup
}

enum TrainingDefaults {
  static let workingSetCount = 3
  static let repetitionCount = 10
}

enum WeightUnit: String, Codable, CaseIterable {
  // Keep these raw values stable for persisted data; UI copy lives below.
  case pounds = "lb"
  case kilograms = "kg"

  var displayAbbreviation: String {
    switch self {
    case .pounds: "lbs"
    case .kilograms: "kgs"
    }
  }

  var spokenName: String {
    switch self {
    case .pounds: "pounds"
    case .kilograms: "kilograms"
    }
  }

  func convert(_ value: Decimal, to targetUnit: WeightUnit) -> Decimal {
    guard self != targetUnit else { return value }

    let poundsToKilograms = Decimal(45_359_237) / Decimal(100_000_000)

    return switch (self, targetUnit) {
    case (.pounds, .kilograms):
      value * poundsToKilograms
    case (.kilograms, .pounds):
      value / poundsToKilograms
    default:
      value
    }
  }
}

struct VolumeLoad: Equatable {
  let value: Decimal
  let unit: WeightUnit

  static func forSet(
    kind: ExerciseSetKind,
    repetitions: Int,
    repetitionMode: ExerciseRepetitionMode = .standard,
    weight: Decimal?,
    unit: WeightUnit?
  ) -> VolumeLoad? {
    guard
      kind == .working,
      repetitions > 0,
      let weight,
      weight >= 0,
      let unit
    else {
      return nil
    }

    // A per-side set records equal repetitions on both sides, with weight per repetition.
    let sideCount: Decimal = repetitionMode == .perSide ? 2 : 1
    return VolumeLoad(value: Decimal(repetitions) * sideCount * weight, unit: unit)
  }

  var formattedValue: String {
    value.formatted(.number.precision(.fractionLength(0...1)))
  }

  var displayText: String {
    "\(formattedValue) \(unit.displayAbbreviation)"
  }

  var accessibilityText: String {
    "\(formattedValue) \(unit.spokenName)"
  }

  func converted(to targetUnit: WeightUnit) -> VolumeLoad {
    VolumeLoad(value: unit.convert(value, to: targetUnit), unit: targetUnit)
  }
}

enum WorkoutModelError: Error, Equatable {
  case activeWorkoutExists
  case cannotRemoveLastSet
  case duplicateExerciseName
  case duplicateExerciseInTemplate
  case duplicateTemplateName
  case emptyName
  case endBeforeStart
  case exerciseHasAssociatedData
  case exerciseClassificationInUse
  case exerciseIsArchived
  case invalidPlannedSetCount
  case invalidPosition
  case invalidReps
  case invalidWeight
  case invalidWeightPrecision
  case missingExercise
  case missingWeight
  case missingWeightUnit
  case seededExerciseIsReadOnly
  case templateIsArchived
  case unexpectedWeightUnit
  case workoutAlreadyCompleted
  case workoutHasNoSets
  case workoutIsNotInProgress
}

struct TemplateExercisePlan {
  let exercise: Exercise
  let plannedWorkingSetCount: Int?
}

extension Decimal {
  var hasAtMostOneFractionalDigit: Bool {
    var source = self
    var rounded = Decimal()
    NSDecimalRound(&rounded, &source, 1, .plain)
    return rounded == self
  }
}
