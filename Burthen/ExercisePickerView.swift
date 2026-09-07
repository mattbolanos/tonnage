//
//  ExercisePickerView.swift
//  Burthen
//

import SwiftData
import SwiftUI

/// Stages exercise choices until the caller successfully adds them.
struct ExercisePickerView: View {
  @Environment(\.dismiss) private var dismiss

  @Query(
    filter: #Predicate<Exercise> { !$0.isArchived },
    sort: \Exercise.name
  )
  private var activeExercises: [Exercise]

  var existingExerciseIDs: Set<UUID> = []
  /// Informational membership for active workouts; these exercises remain selectable.
  var inWorkoutExerciseIDs: Set<UUID> = []
  let onAdd: ([Exercise]) throws -> Void
  var errorMessage: (Error) -> String = { $0.localizedDescription }

  @State private var selectedExerciseIDs: [UUID] = []
  @State private var searchText = ""
  @State private var isSearchPresented = false
  @State private var isAddingExercise = false
  @State private var isShowingError = false
  @State private var errorText = ""

  private var filteredExercises: [Exercise] {
    guard !searchText.isEmpty else { return activeExercises }
    return activeExercises.filter {
      $0.name.localizedStandardContains(searchText)
    }
  }

  private var canShowNewExercise: Bool {
    !isSearchPresented && searchText.isEmpty
  }

  private var selectedExercises: [Exercise] {
    selectedExerciseIDs.compactMap { exerciseID in
      activeExercises.first {
        $0.id == exerciseID && !existingExerciseIDs.contains(exerciseID)
      }
    }
  }

  private var exercisesNotInWorkout: [Exercise] {
    filteredExercises.filter { !inWorkoutExerciseIDs.contains($0.id) }
  }

  private var exercisesInWorkout: [Exercise] {
    filteredExercises.filter { inWorkoutExerciseIDs.contains($0.id) }
  }

  private var confirmationTitle: LocalizedStringKey {
    switch selectedExercises.count {
    case 0: "Add Exercises"
    case 1: "Add 1 Exercise"
    case let count: "Add \(count) Exercises"
    }
  }

  var body: some View {
    NavigationStack {
      List {
        if !filteredExercises.isEmpty {
          if canShowNewExercise {
            Section {
              Button(action: addExercise) {
                Label("New Exercise", systemImage: "plus")
                  .foregroundStyle(.pink)
              }
            }
          }
          if !exercisesNotInWorkout.isEmpty {
            Section {
              ForEach(exercisesNotInWorkout) { exercise in
                ExercisePickerRow(
                  exercise: exercise,
                  isAlreadyAdded: existingExerciseIDs.contains(exercise.id),
                  isSelected: selectedExerciseIDs.contains(exercise.id),
                  action: { toggleSelection(of: exercise) }
                )
              }
            }
          }

          if !exercisesInWorkout.isEmpty {
            Section {
              ForEach(exercisesInWorkout) { exercise in
                ExercisePickerRow(
                  exercise: exercise,
                  isAlreadyAdded: existingExerciseIDs.contains(exercise.id),
                  isSelected: selectedExerciseIDs.contains(exercise.id),
                  isInWorkout: true,
                  action: { toggleSelection(of: exercise) }
                )
              }
            } header: {
              Text("Already in Workout")
            }
          }

        }
      }
      .overlay {
        if activeExercises.isEmpty {
          ContentUnavailableView {
            ContentUnavailableLogoLabel(title: "No Exercises Yet")
          } description: {
            Text("Create an exercise to add it to your library and select it here.")
          } actions: {
            if canShowNewExercise {
              Button("New Exercise", systemImage: "plus", action: addExercise)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
          }
        } else if filteredExercises.isEmpty {
          ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
          } description: {
            Text("No exercises match “\(searchText)”.")
          } actions: {
            Button("Clear Search", action: clearSearch)
              .buttonStyle(.borderedProminent)
              .controlSize(.large)
          }
        }
      }
      .searchable(
        text: $searchText,
        isPresented: $isSearchPresented,
        prompt: "Search Exercises"
      )
      .navigationTitle("Add Exercises")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: dismiss.callAsFunction)
            .tint(.primary)
        }
      }
      .safeAreaInset(edge: .bottom) {
        Button(action: addSelectedExercises) {
          Text(confirmationTitle)
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(selectedExercises.isEmpty)
        .accessibilityIdentifier("confirm-add-exercises")
        .accessibilityInputLabels(["Add Exercises", "Add"])
        .padding(.horizontal, LayoutMetrics.Padding.horizontalContent)
        .padding(.vertical, LayoutMetrics.Spacing.small)
      }
      .sheet(isPresented: $isAddingExercise) {
        AddExerciseView(onAdd: selectNewExercise)
      }
      .alert("Exercises Couldn’t Be Added", isPresented: $isShowingError) {
      } message: {
        Text(errorText)
      }
    }
    .tint(.pink)
  }

  private func addExercise() {
    isAddingExercise = true
  }

  private func clearSearch() {
    searchText = ""
  }

  private func selectNewExercise(_ exercise: Exercise) {
    searchText = ""
    guard !existingExerciseIDs.contains(exercise.id) else { return }
    selectedExerciseIDs.append(exercise.id)
  }

  private func toggleSelection(of exercise: Exercise) {
    if selectedExerciseIDs.contains(exercise.id) {
      selectedExerciseIDs.removeAll { $0 == exercise.id }
    } else {
      selectedExerciseIDs.append(exercise.id)
    }
  }

  private func addSelectedExercises() {
    guard !selectedExercises.isEmpty else { return }

    do {
      try onAdd(selectedExercises)
      dismiss()
    } catch {
      errorText = errorMessage(error)
      isShowingError = true
    }
  }
}
