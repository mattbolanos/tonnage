//
//  ActiveWorkoutExerciseView.swift
//  Burthen
//

import SwiftData
import SwiftUI

struct ActiveWorkoutExerciseView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.modelContext) private var modelContext
  @ScaledMetric(relativeTo: .body)
  private var setNumberColumnWidth = LayoutMetrics.Size.setNumberColumn

  let workoutExercise: WorkoutExercise
  let onNextExercise: (UUID) -> Void
  let onReturnToWorkout: () -> Void

  // NavigationLink may initialize this destination while deleting its source row.
  // Defer SwiftData reads until the destination appears so the model is still attached.
  @State private var weightUnit = WeightUnit.pounds
  @State private var setDisplayMode = ExerciseSetDisplayMode.repetitionsAndWeight
  @State private var isShowingError = false
  @State private var errorMessage = ""
  @State private var selectedSet: ExerciseSet?
  @State private var completedSetFeedbackCount = 0

  private var exerciseName: String {
    workoutExercise.exercise?.name ?? "Unavailable Exercise"
  }

  private var requiresWeight: Bool {
    workoutExercise.exercise?.loadMode == .externalResistance
  }

  var body: some View {
    let orderedSets = workoutExercise.orderedSets
    let progression = ActiveWorkoutProgression.afterCompleting(workoutExercise)

    List {
      Section {
        ForEach(
          Array(orderedSets.enumerated()),
          id: \.element.id
        ) { index, exerciseSet in
          ExerciseSetEditorRow(
            exerciseSet: exerciseSet,
            setNumber: index + 1,
            weightUnit: weightUnit,
            requiresWeight: requiresWeight,
            displayMode: setDisplayMode,
            canDelete: orderedSets.count > 1,
            edit: editSet,
            setCompletion: setCompletion,
            remove: removeSet
          )
          .deleteDisabled(orderedSets.count <= 1)
        }
        .onDelete(perform: removeSets)

        Button(action: addSet) {
          HStack(
            alignment: .firstTextBaseline,
            spacing: LayoutMetrics.Spacing.medium
          ) {
            Image(systemName: "plus")
              .frame(
                width: setNumberColumnWidth,
                alignment: .leading
              )
              .accessibilityHidden(true)

            Text("Add Set")
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(.rect)
        }
        .tint(.pink)
        .accessibilityLabel("Add Set")
      } header: {
        SectionHeader("Sets")
      } footer: {
        if workoutExercise.exercise?.repetitionMode == .perSide {
          Text("Reps are per side. Mark a set complete after finishing both sides.")
        }
      }
      .listSectionMargins(
        .horizontal,
        LayoutMetrics.Padding.horizontalContent
      )

      if let progression {
        Section {
          WorkoutExerciseContinuation(
            progression: progression,
            onNextExercise: onNextExercise,
            onReturnToWorkout: onReturnToWorkout
          )
          .listRowBackground(Color.clear)
        } header: {
          SectionHeader("Working Sets Complete")
        }
        .listSectionMargins(
          .horizontal,
          LayoutMetrics.Padding.horizontalContent
        )
      }
    }
    .contentMargins(
      .top,
      LayoutMetrics.Spacing.small,
      for: .scrollContent
    )
    .listSectionSpacing(.compact)
    .animation(reduceMotion ? nil : .smooth, value: progression)
    .navigationTitle(exerciseName)
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu("Exercise Options", systemImage: "ellipsis") {
          Section("Set Display") {
            Picker("Set Display", selection: $setDisplayMode) {
              Text("Reps × Weight")
                .tag(ExerciseSetDisplayMode.repetitionsAndWeight)
              Text("Set Load")
                .tag(ExerciseSetDisplayMode.setLoad)
            }
            .pickerStyle(.inline)
            .labelsHidden()
          }

          Section("Weight Unit") {
            Picker("Weight Unit", selection: $weightUnit) {
              Text("Pounds (lbs)")
                .tag(WeightUnit.pounds)
              Text("Kilograms (kgs)")
                .tag(WeightUnit.kilograms)
            }
            .pickerStyle(.inline)
            .labelsHidden()
          }
        }
        .labelStyle(.iconOnly)
      }

      ToolbarItem(placement: .topBarTrailing) {
        EditButton()
      }
    }
    .onAppear(perform: prepareWeightUnit)
    .onChange(of: weightUnit, updateWeightUnit)
    .sensoryFeedback(.success, trigger: completedSetFeedbackCount)
    .sheet(item: $selectedSet) { exerciseSet in
      ExerciseSetPicker(
        exerciseSet: exerciseSet,
        setNumber: exerciseSet.position + 1,
        weightUnit: weightUnit
      )
    }
    .alert("Workout Couldn’t Be Updated", isPresented: $isShowingError) {
    } message: {
      Text(errorMessage)
    }
  }

  private func prepareWeightUnit() {
    let storedWeightUnit = workoutExercise.weightUnit
    if weightUnit != storedWeightUnit {
      weightUnit = storedWeightUnit
    } else if workoutExercise.requiresWeightUnitUpdate(to: storedWeightUnit) {
      persistWeightUnit(storedWeightUnit)
    }
  }

  private func updateWeightUnit() {
    persistWeightUnit(weightUnit)
  }

  private func persistWeightUnit(_ weightUnit: WeightUnit) {
    performUpdate {
      try TrainingDataStore(modelContext: modelContext).updateWeightUnit(
        for: workoutExercise,
        to: weightUnit
      )
    }
  }

  private func editSet(_ exerciseSet: ExerciseSet) {
    selectedSet = exerciseSet
  }

  private func addSet() {
    performUpdate {
      _ = try TrainingDataStore(modelContext: modelContext).addSet(
        to: workoutExercise
      )
    }
  }

  private func removeSet(_ exerciseSet: ExerciseSet) {
    performUpdate {
      try TrainingDataStore(modelContext: modelContext).remove(
        exerciseSet,
        from: workoutExercise
      )
    }
  }

  private func setCompletion(_ isCompleted: Bool, for exerciseSet: ExerciseSet) {
    let wasCompleted = exerciseSet.isCompleted
    let didSave = performUpdate {
      try TrainingDataStore(modelContext: modelContext).setCompletion(
        isCompleted,
        for: exerciseSet
      )
    }

    if didSave && isCompleted && !wasCompleted {
      completedSetFeedbackCount += 1
    }
  }

  private func removeSets(at offsets: IndexSet) {
    let exerciseSets = offsets.map { workoutExercise.orderedSets[$0] }
    guard exerciseSets.count < workoutExercise.exerciseSets.count else { return }

    performUpdate {
      let store = TrainingDataStore(modelContext: modelContext)
      for exerciseSet in exerciseSets {
        try store.remove(exerciseSet, from: workoutExercise)
      }
    }
  }

  @discardableResult
  private func performUpdate(_ update: () throws -> Void) -> Bool {
    do {
      try update()
      try modelContext.save()
      return true
    } catch {
      modelContext.rollback()
      errorMessage = activeWorkoutErrorMessage(for: error)
      isShowingError = true
      return false
    }
  }
}
