//
//  Workout.swift
//  Burthen
//


import Foundation
import SwiftData

@Model
final class Workout {
  var id: UUID = UUID()
  var name: String?
  var notes: String?
  var status: WorkoutStatus = WorkoutStatus.inProgress
  var startedAt: Date = Date.now
  var endedAt: Date?
  var timeZoneIdentifier: String = TimeZone.current.identifier
  var createdAt: Date = Date.now
  var updatedAt: Date = Date.now
  var sourceTemplate: WorkoutTemplate?

  @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
  var workoutExercises: [WorkoutExercise] = []

  init(
    id: UUID = UUID(),
    name: String? = nil,
    notes: String? = nil,
    status: WorkoutStatus = .inProgress,
    startedAt: Date = .now,
    endedAt: Date? = nil,
    timeZoneIdentifier: String = TimeZone.current.identifier,
    createdAt: Date = .now,
    updatedAt: Date = .now,
    sourceTemplate: WorkoutTemplate? = nil
  ) throws {
    if let endedAt, endedAt < startedAt {
      throw WorkoutModelError.endBeforeStart
    }

    self.id = id
    self.name = name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    self.status = status
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.timeZoneIdentifier = timeZoneIdentifier
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.sourceTemplate = sourceTemplate
  }

  var orderedExercises: [WorkoutExercise] {
    workoutExercises.sorted { lhs, rhs in
      if lhs.position == rhs.position {
        lhs.id.uuidString < rhs.id.uuidString
      } else {
        lhs.position < rhs.position
      }
    }
  }

  var displayName: String {
    name ?? defaultName()
  }

  var volumeLoadUnit: WeightUnit {
    orderedExercises.first { workoutExercise in
      workoutExercise.exercise?.loadMode == .externalResistance
    }?.weightUnit
      ?? orderedExercises.compactMap { workoutExercise in
        workoutExercise.orderedSets.compactMap(\.weightUnit).first
      }.first
      ?? .pounds
  }

  var volumeLoad: VolumeLoad? {
    volumeLoad(in: volumeLoadUnit)
  }

  func defaultName() -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current

    switch calendar.component(.hour, from: startedAt) {
    case 0..<12:
      return "Morning Lift"
    case 12..<17:
      return "Afternoon Lift"
    default:
      return "Evening Lift"
    }
  }

  var isCompletable: Bool {
    workoutExercises.contains { workoutExercise in
      workoutExercise.exerciseSets.contains { $0.isCompleted }
    }
  }

  func elapsedDuration(at currentDate: Date = .now) -> TimeInterval? {
    let effectiveEnd: Date?
    if let endedAt {
      effectiveEnd = endedAt
    } else if status == .inProgress {
      effectiveEnd = currentDate
    } else {
      effectiveEnd = nil
    }

    guard let effectiveEnd, effectiveEnd >= startedAt else { return nil }
    return effectiveEnd.timeIntervalSince(startedAt)
  }

  @discardableResult
  func addExercise(
    _ exercise: Exercise,
    plannedWorkingSetCount: Int? = nil,
    at date: Date = .now
  ) throws -> WorkoutExercise {
    guard !exercise.isArchived else { throw WorkoutModelError.exerciseIsArchived }

    let workoutExercise = try WorkoutExercise(
      position: nextExercisePosition,
      plannedWorkingSetCount: plannedWorkingSetCount,
      workout: self,
      exercise: exercise
    )
    workoutExercises.append(workoutExercise)
    updatedAt = date
    return workoutExercise
  }

  func removeExercise(
    _ workoutExercise: WorkoutExercise,
    at date: Date = .now
  ) {
    guard workoutExercise.workout === self else { return }

    workoutExercises.removeAll { $0 === workoutExercise }
    workoutExercise.workout = nil
    normalizeExercisePositions()
    updatedAt = date
  }

  func updateExerciseOrder(
    _ orderedExercises: [WorkoutExercise],
    at date: Date = .now
  ) {
    let currentIDs = Set(workoutExercises.map(\.id))
    let proposedIDs = Set(orderedExercises.map(\.id))
    guard
      orderedExercises.count == workoutExercises.count,
      proposedIDs == currentIDs
    else { return }

    for (position, workoutExercise) in orderedExercises.enumerated() {
      workoutExercise.position = position
    }
    updatedAt = date
  }

  func complete(at endDate: Date? = .now) throws {
    guard status == .inProgress else { throw WorkoutModelError.workoutAlreadyCompleted }
    guard isCompletable else { throw WorkoutModelError.workoutHasNoSets }

    if let endDate, endDate < startedAt {
      throw WorkoutModelError.endBeforeStart
    }

    for exerciseSet in workoutExercises.flatMap(\.exerciseSets)
    where exerciseSet.isCompleted {
      try exerciseSet.validate()
    }

    endedAt = endDate
    status = .completed
    updatedAt = endDate ?? .now
  }

  func updateTiming(
    startedAt: Date,
    endedAt: Date?,
    timeZoneIdentifier: String,
    at date: Date = .now
  ) throws {
    if let endedAt, endedAt < startedAt {
      throw WorkoutModelError.endBeforeStart
    }

    self.startedAt = startedAt
    self.endedAt = endedAt
    self.timeZoneIdentifier = timeZoneIdentifier
    updatedAt = date
  }

  func volumeLoad(in unit: WeightUnit) -> VolumeLoad? {
    let values = workoutExercises.compactMap { $0.volumeLoad(in: unit)?.value }
    guard !values.isEmpty else { return nil }

    return VolumeLoad(value: values.reduce(Decimal.zero, +), unit: unit)
  }

  func volumeLoad(for exerciseID: UUID, in unit: WeightUnit) -> VolumeLoad? {
    let values = workoutExercises
      .filter { $0.exercise?.id == exerciseID }
      .compactMap { $0.volumeLoad(in: unit)?.value }
    guard !values.isEmpty else { return nil }

    return VolumeLoad(value: values.reduce(Decimal.zero, +), unit: unit)
  }

  var templateExercisePlans: [TemplateExercisePlan] {
    orderedExercises.compactMap { workoutExercise in
      guard let exercise = workoutExercise.exercise else { return nil }

      let currentWorkingSetCount = workoutExercise.exerciseSets.count {
        $0.kind == .working
      }
      let plannedWorkingSetCount = currentWorkingSetCount > 0
        ? currentWorkingSetCount
        : workoutExercise.plannedWorkingSetCount ?? TrainingDefaults.workingSetCount

      return TemplateExercisePlan(
        exercise: exercise,
        plannedWorkingSetCount: plannedWorkingSetCount
      )
    }
  }

  func makeTemplate(
    named name: String,
    notes: String? = nil,
    at date: Date = .now
  ) throws -> WorkoutTemplate {
    let template = try WorkoutTemplate(name: name, notes: notes, createdAt: date, updatedAt: date)

    for plan in templateExercisePlans {
      try template.addExercise(
        plan.exercise,
        plannedWorkingSetCount: plan.plannedWorkingSetCount,
        at: date
      )
    }

    return template
  }

  private var nextExercisePosition: Int {
    (workoutExercises.map(\.position).max() ?? -1) + 1
  }

  private func normalizeExercisePositions() {
    for (position, workoutExercise) in orderedExercises.enumerated() {
      workoutExercise.position = position
    }
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
