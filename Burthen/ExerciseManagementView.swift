//
//  ExerciseManagementView.swift
//  Burthen
//

import Foundation
import SwiftData
import SwiftUI

struct ExerciseManagementView: View {
  @Environment(\.modelContext) private var modelContext

  @Query(
    filter: #Predicate<Exercise> { !$0.isArchived },
    sort: \Exercise.name
  )
  private var activeExercises: [Exercise]

  @Query(
    filter: #Predicate<Exercise> { $0.isArchived },
    sort: \Exercise.name
  )
  private var archivedExercises: [Exercise]

  @State private var isAddingExercise = false
  @State private var isConfirmingDeletion = false
  @State private var pendingDeletion: ExerciseDeletionRequest?
  @State private var isShowingError = false
  @State private var errorMessage = ""

  private var hasExercises: Bool {
    !activeExercises.isEmpty || !archivedExercises.isEmpty
  }

  var body: some View {
    List {
      if !activeExercises.isEmpty {
        Section {
          ForEach(activeExercises) { exercise in
            ExerciseNavigationRow(exercise: exercise)
              .deleteDisabled(exercise.origin == .seeded)
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if exercise.origin == .custom {
                  Button(
                    "Delete Exercise",
                    systemImage: "trash",
                    role: .destructive
                  ) {
                    requestDeletion(of: exercise)
                  }
                  .labelStyle(.iconOnly)
                }
              }
          }
          .onDelete(perform: removeActiveExercises)
        } header: {
          SectionHeader("Active")
        }
      }

      if !archivedExercises.isEmpty {
        Section {
          ForEach(archivedExercises) { exercise in
            ExerciseNavigationRow(exercise: exercise)
              .deleteDisabled(exercise.origin == .seeded)
              .swipeActions(edge: .leading) {
                if exercise.origin == .custom {
                  Button("Restore", systemImage: "arrow.uturn.backward") {
                    restore(exercise)
                  }
                }
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if exercise.origin == .custom {
                  Button(
                    "Delete Exercise",
                    systemImage: "trash",
                    role: .destructive
                  ) {
                    requestDeletion(of: exercise)
                  }
                  .labelStyle(.iconOnly)
                }
              }
          }
          .onDelete(perform: removeArchivedExercises)
        } header: {
          SectionHeader("Archived")
        }
      }
    }
    .overlay {
      if !hasExercises {
        ContentUnavailableView {
          ContentUnavailableLogoLabel(title: "No Exercises")
        } description: {
          Text("Add an exercise to use it in workouts and templates.")
        } actions: {
          Button("Add Exercise", systemImage: "plus", action: addExercise)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.pink)
        }
      }
    }
    .navigationTitle("Exercises")
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        EditButton()
        Button("Add Exercise", systemImage: "plus", action: addExercise)
      }
    }
    .sheet(isPresented: $isAddingExercise) {
      AddExerciseView()
    }
    .alert(
      "Remove Exercise?",
      isPresented: $isConfirmingDeletion,
      presenting: pendingDeletion
    ) { request in
      if !request.exercise.isArchived {
        Button("Archive") {
          archive(request.exercise)
        }
      }
      Button(request.deleteButtonTitle, role: .destructive) {
        delete(
          request.exercise,
          includingAssociatedData: request.impact.hasAssociatedData
        )
      }
      Button("Cancel", role: .cancel, action: cancelDeletion)
    } message: { request in
      Text(request.message)
    }
    .alert("Exercise Couldn’t Be Updated", isPresented: $isShowingError) {
      Button("OK", role: .cancel) { }
    } message: {
      Text(errorMessage)
    }
  }

  private func addExercise() {
    isAddingExercise = true
  }

  private func removeActiveExercises(at offsets: IndexSet) {
    guard let exercise = offsets.lazy
      .map({ activeExercises[$0] })
      .first(where: { $0.origin == .custom })
    else { return }

    requestDeletion(of: exercise)
  }

  private func removeArchivedExercises(at offsets: IndexSet) {
    guard let exercise = offsets.lazy
      .map({ archivedExercises[$0] })
      .first(where: { $0.origin == .custom })
    else { return }

    requestDeletion(of: exercise)
  }

  private func requestDeletion(of exercise: Exercise) {
    let store = TrainingDataStore(modelContext: modelContext)
    let impact = store.deletionImpact(for: exercise)

    guard !exercise.isArchived || impact.hasAssociatedData else {
      delete(exercise, includingAssociatedData: false)
      return
    }

    pendingDeletion = ExerciseDeletionRequest(
      exercise: exercise,
      impact: impact
    )
    isConfirmingDeletion = true
  }

  private func archive(_ exercise: Exercise) {
    performUpdate {
      try TrainingDataStore(modelContext: modelContext).archive(exercise)
    }
    pendingDeletion = nil
  }

  private func restore(_ exercise: Exercise) {
    performUpdate {
      try TrainingDataStore(modelContext: modelContext).restore(exercise)
    }
  }

  private func delete(
    _ exercise: Exercise,
    includingAssociatedData: Bool
  ) {
    performUpdate {
      try TrainingDataStore(modelContext: modelContext).delete(
        exercise,
        includingAssociatedData: includingAssociatedData
      )
    }
    pendingDeletion = nil
  }

  private func cancelDeletion() {
    pendingDeletion = nil
  }

  private func performUpdate(_ update: () throws -> Void) {
    do {
      try update()
      try modelContext.save()
    } catch {
      errorMessage = exerciseErrorMessage(for: error)
      isShowingError = true
    }
  }
}

private struct ExerciseNavigationRow: View {
  let exercise: Exercise

  var body: some View {
    NavigationLink {
      EditExerciseView(exercise: exercise)
    } label: {
      ExerciseRowView(exercise: exercise)
    }
  }
}

private struct ExerciseRowView: View {
  let exercise: Exercise

  var body: some View {
    Text(exercise.name)
  }
}

private struct ExerciseDeletionRequest {
  let exercise: Exercise
  let impact: ExerciseDeletionImpact

  var deleteButtonTitle: String {
    impact.hasAssociatedData ? "Delete Exercise & Data" : "Delete Exercise"
  }

  var message: String {
    guard impact.hasAssociatedData else {
      return "Archiving hides \(exercise.name) from future workouts. Deleting permanently removes it."
    }

    let associatedData = ListFormatter.localizedString(
      byJoining: [
        impact.workoutEntryCount.formatted(
          singular: "workout entry",
          plural: "workout entries"
        ),
        impact.setCount.formatted(singular: "set", plural: "sets"),
        impact.templateEntryCount.formatted(
          singular: "template entry",
          plural: "template entries"
        ),
      ].filter { !$0.hasPrefix("0 ") }
    )
    let alternative = exercise.isArchived
      ? "Keeping it archived preserves this data."
      : "Archive it instead to preserve this data."

    return "Deleting \(exercise.name) permanently removes \(associatedData). \(alternative)"
  }
}

private extension Exercise {
  var summary: String {
    let load = switch loadMode {
    case .externalResistance: "External Resistance"
    case .bodyweight: "Bodyweight"
    }
    let repetitions = switch repetitionMode {
    case .standard: "Standard Reps"
    case .perSide: "Per Side"
    }
    let originLabel = origin == .seeded ? "Built-in" : nil
    let startingWeightLabel = startingWorkingWeight.flatMap { weight in
      startingWorkingWeightUnit.map { unit in
        "Starts at \(weight.formatted(.number.precision(.fractionLength(0...1)))) \(unit.displayAbbreviation)"
      }
    }

    return [load, repetitions, startingWeightLabel, originLabel]
      .compactMap { $0 }
      .joined(separator: " · ")
  }
}

private extension Int {
  func formatted(singular: String, plural: String) -> String {
    "\(self) \(self == 1 ? singular : plural)"
  }
}

func exerciseErrorMessage(for error: Error) -> String {
  guard let modelError = error as? WorkoutModelError else {
    return error.localizedDescription
  }

  return switch modelError {
  case .duplicateExerciseName:
    "An active exercise already uses this name."
  case .emptyName:
    "Enter a name for the exercise."
  case .exerciseHasAssociatedData:
    "This exercise still has associated workout or template data."
  case .exerciseClassificationInUse:
    "Load and repetition tracking can’t be changed after sets have been logged."
  case .invalidWeight:
    "Enter a starting working weight of zero or more."
  case .invalidWeightPrecision:
    "Enter a starting working weight with no more than one decimal place."
  case .seededExerciseIsReadOnly:
    "Built-in exercises can’t be changed."
  default:
    "The exercise couldn’t be updated."
  }
}

#Preview {
  NavigationStack {
    ExerciseManagementView()
  }
  .modelContainer(for: BurthenSchema.models, inMemory: true)
}
