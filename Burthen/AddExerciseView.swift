//
//  AddExerciseView.swift
//  Burthen
//

import Foundation
import SwiftData
import SwiftUI

struct AddExerciseView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let onAdd: (Exercise) -> Void

  @State private var name = ""
  @State private var loadMode = ExerciseLoadMode.externalResistance
  @State private var repetitionMode = ExerciseRepetitionMode.standard
  @State private var startingWorkingWeightText = ""
  @State private var startingWorkingWeightUnit = WeightUnit.pounds
  @State private var isShowingError = false
  @State private var errorMessage = ""

  private var canSave: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && StartingWorkingWeightInput.isValid(startingWorkingWeightText)
  }

  init(onAdd: @escaping (Exercise) -> Void = { _ in }) {
    self.onAdd = onAdd
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Name", text: $name)
            .textInputAutocapitalization(.words)
        } header: {
          SectionHeader("Exercise")
        }

        Section {
          Picker("Load", selection: $loadMode) {
            Text("External Resistance")
              .tag(ExerciseLoadMode.externalResistance)
            Text("Bodyweight")
              .tag(ExerciseLoadMode.bodyweight)
          }

          Picker("Repetitions", selection: $repetitionMode) {
            Text("Standard")
              .tag(ExerciseRepetitionMode.standard)
            Text("Per Side")
              .tag(ExerciseRepetitionMode.perSide)
          }
        } header: {
          SectionHeader("Tracking")
        }

        StartingWorkingWeightSection(
          weightText: $startingWorkingWeightText,
          weightUnit: $startingWorkingWeightUnit
        )
      }
      .navigationTitle("New Exercise")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: dismiss.callAsFunction)
            .tint(.primary)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create", action: save)
            .tint(.primary)
            .disabled(!canSave)
        }
      }
      .alert("Exercise Couldn’t Be Added", isPresented: $isShowingError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage)
      }
    }
  }

  private func save() {
    do {
      let exercise = try TrainingDataStore(modelContext: modelContext).createExercise(
        name: name,
        loadMode: loadMode,
        repetitionMode: repetitionMode,
        startingWorkingWeight: StartingWorkingWeightInput.value(
          from: startingWorkingWeightText
        ),
        startingWorkingWeightUnit: startingWorkingWeightUnit
      )
      try modelContext.save()
      onAdd(exercise)
      dismiss()
    } catch {
      errorMessage = exerciseErrorMessage(for: error)
      isShowingError = true
    }
  }
}

#Preview {
  AddExerciseView()
    .modelContainer(for: BurthenSchema.models, inMemory: true)
}
