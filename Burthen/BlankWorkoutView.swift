//
//  BlankWorkoutView.swift
//  Burthen
//

import SwiftData
import SwiftUI

struct BlankWorkoutView: View {
  @Environment(\.modelContext) private var modelContext

  @Query(filter: #Predicate<Exercise> { !$0.isArchived })
  private var libraryExercises: [Exercise]

  @State private var exercises: [BlankWorkoutExerciseDraft] = []
  @State private var presentedSheet: BlankWorkoutSheet?
  @State private var isShowingError = false
  @State private var errorMessage = ""

  var body: some View {
    List {
      if !exercises.isEmpty {
        Section {
          ForEach(exercises) { draft in
            BlankWorkoutExerciseRow(exercise: draft.exercise)
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(
                  "Delete Exercise",
                  systemImage: "trash",
                  role: .destructive
                ) {
                  removeExercise(draft)
                }
                .labelStyle(.iconOnly)
              }
          }
          .onDelete(perform: removeExercises)
          .onMove(perform: moveExercises)
        } header: {
          SectionHeader("Exercises")
        }

        BlankWorkoutActions(
          saveTemplate: presentTemplateEditor,
          startWorkout: startWorkout
        )
        .listRowInsets(.init())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      }
    }
    .overlay {
      if exercises.isEmpty {
        BlankWorkoutEmptyState(
          hasLibraryExercises: !libraryExercises.isEmpty,
          createExercise: addExercise,
          chooseExercises: selectExercises
        )
        .padding(.horizontal, LayoutMetrics.Padding.horizontalContent)
      }
    }
    .navigationTitle("Blank Workout")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !exercises.isEmpty {
        ToolbarItemGroup(placement: .topBarTrailing) {
          EditButton()
          Button(
            "Add Exercises",
            systemImage: "plus",
            action: selectExercises
          )
        }
      }
    }
    .sheet(item: $presentedSheet) { sheet in
      switch sheet {
      case .exercisePicker:
        ExercisePickerView(
          existingExerciseIDs: Set(exercises.map { $0.exercise.id }),
          onAdd: appendExercises
        )
      case .newExercise:
        AddExerciseView(onAdd: appendExercise)
      case .template(let seed):
        AddWorkoutTemplateView(seed: seed)
      }
    }
    .alert("Workout Couldn’t Be Started", isPresented: $isShowingError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage)
    }
  }

  private func selectExercises() {
    presentedSheet = .exercisePicker
  }

  private func addExercise() {
    presentedSheet = .newExercise
  }

  private func appendExercise(_ exercise: Exercise) {
    exercises.append(BlankWorkoutExerciseDraft(exercise: exercise))
  }

  private func appendExercises(_ selectedExercises: [Exercise]) {
    exercises.append(contentsOf: selectedExercises.map {
      BlankWorkoutExerciseDraft(exercise: $0)
    })
  }

  private func removeExercises(at offsets: IndexSet) {
    exercises.remove(atOffsets: offsets)
  }

  private func removeExercise(_ exercise: BlankWorkoutExerciseDraft) {
    exercises.removeAll { $0.id == exercise.id }
  }

  private func moveExercises(from offsets: IndexSet, to destination: Int) {
    exercises.move(fromOffsets: offsets, toOffset: destination)
  }

  private func presentTemplateEditor() {
    presentedSheet = .template(
      WorkoutTemplateSeed(exercises: exercises.map(\.exercise))
    )
  }

  private func startWorkout() {
    guard !exercises.isEmpty else { return }

    do {
      let store = TrainingDataStore(modelContext: modelContext)
      let workout = try store.startWorkout()
      for draft in exercises {
        try store.addExercise(draft.exercise, to: workout)
      }
      try modelContext.save()
    } catch {
      modelContext.rollback()
      errorMessage = blankWorkoutErrorMessage(for: error)
      isShowingError = true
    }
  }
}

private enum BlankWorkoutSheet: Identifiable {
  case exercisePicker
  case newExercise
  case template(WorkoutTemplateSeed)

  var id: String {
    switch self {
    case .exercisePicker:
      "exercise-picker"
    case .newExercise:
      "new-exercise"
    case .template(let seed):
      "template-\(seed.id)"
    }
  }
}

private struct BlankWorkoutActions: View {
  let saveTemplate: () -> Void
  let startWorkout: () -> Void

  var body: some View {
    VStack(spacing: LayoutMetrics.Spacing.small) {
      Button(action: startWorkout) {
        Text("Start Workout")
          .font(.headline)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.glassProminent)
      .controlSize(.large)
      .tint(.pink)
      .accessibilityHint("Starts a workout with these exercises.")

      Button(action: saveTemplate) {
        Label(
          "Save as Template",
          systemImage: "rectangle.stack.badge.plus"
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderless)
      .controlSize(.large)
      .accessibilityHint(
        "Creates a reusable template from these exercises."
      )
    }
  }
}

private struct BlankWorkoutEmptyState: View {
  let hasLibraryExercises: Bool
  let createExercise: () -> Void
  let chooseExercises: () -> Void

  var body: some View {
    ContentUnavailableView {
      ContentUnavailableLogoLabel(
        title: hasLibraryExercises ? "Choose Your Exercises" : "Add Your First Exercise"
      )
    } description: {
      Text(
        hasLibraryExercises
          ? "Add exercises from your library to build this workout."
          : "Create an exercise to start building your workout."
      )
    } actions: {
      Button(
        hasLibraryExercises ? "Add Exercises" : "New Exercise",
        systemImage: "plus",
        action: hasLibraryExercises ? chooseExercises : createExercise
      )
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .tint(.pink)

      if hasLibraryExercises {
        Button("New Exercise", action: createExercise)
          .controlSize(.large)
      }
    }
  }
}

private struct BlankWorkoutExerciseRow: View {
  let exercise: Exercise

  var body: some View {
    VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.extraSmall) {
      Text(exercise.name)
        .foregroundStyle(.primary)
      Text(exercise.blankWorkoutTrackingSummary)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}

private struct BlankWorkoutExerciseDraft: Identifiable {
  let id = UUID()
  let exercise: Exercise
}

private extension Exercise {
  var blankWorkoutTrackingSummary: String {
    let load = switch loadMode {
    case .externalResistance: "External resistance"
    case .bodyweight: "Bodyweight"
    }
    let repetitions = repetitionMode == .perSide ? "Per side" : "Standard reps"
    return "\(load) · \(repetitions)"
  }
}

private func blankWorkoutErrorMessage(for error: Error) -> String {
  guard let modelError = error as? WorkoutModelError else {
    return error.localizedDescription
  }

  return switch modelError {
  case .activeWorkoutExists:
    "Finish or discard the active workout before starting another one."
  case .exerciseIsArchived:
    "One of these exercises is no longer available. Remove it and try again."
  default:
    "The workout couldn’t be started."
  }
}

#Preview {
  NavigationStack {
    BlankWorkoutView()
  }
  .modelContainer(for: BurthenSchema.models, inMemory: true)
}
