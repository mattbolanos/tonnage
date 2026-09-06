//
//  ActiveWorkoutView.swift
//  Burthen
//

import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
  let workout: Workout
  @Binding var navigationPath: [ActiveWorkoutExerciseRoute]
  let onComplete: (Workout) -> Void
  let onDiscard: () -> Void
  let onMinimize: () -> Void

  var body: some View {
    NavigationStack(path: $navigationPath) {
      ActiveWorkoutEditor(
        workout: workout,
        navigationPath: $navigationPath,
        onComplete: onComplete,
        onDiscard: onDiscard,
        onMinimize: onMinimize
      )
    }
  }
}

private struct ActiveWorkoutEditor: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.modelContext) private var modelContext

  let workout: Workout
  @Binding var navigationPath: [ActiveWorkoutExerciseRoute]
  let onComplete: (Workout) -> Void
  let onDiscard: () -> Void
  let onMinimize: () -> Void

  @State private var presentedSheet: ActiveWorkoutSheet?
  @State private var isConfirmingDiscard = false
  @State private var isShowingError = false
  @State private var errorMessage = ""

  var body: some View {
    let exerciseSummaries = workout.orderedExercises.map {
      ActiveWorkoutExerciseSummary(workoutExercise: $0)
    }
    let canDeleteExercises = exerciseSummaries.count > 1

    List {
      ActiveWorkoutHeader(workout: workout)

      if exerciseSummaries.isEmpty {
        ActiveWorkoutEmptyState(addExercise: presentExercisePicker)
      } else {
        ForEach(exerciseSummaries) { exercise in
          ExerciseCard(exercise: exercise)
            .listRowInsets(LayoutMetrics.Insets.cardRow)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button(
                "Delete Exercise",
                systemImage: "trash",
                role: .destructive
              ) {
                removeExercise(withID: exercise.id)
              }
              .labelStyle(.iconOnly)
              .disabled(!canDeleteExercises)
            }
            .deleteDisabled(!canDeleteExercises)
        }
        .onDelete { offsets in
          removeExercises(at: offsets, from: exerciseSummaries)
        }
        .onMove(perform: moveExercises)
      }

      Section {
        Button(action: finishWorkout) {
          Label("Finish Workout", systemImage: "checkmark")
            .font(.headline)
            .foregroundStyle(workout.isCompletable ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(.pink)
        .disabled(!workout.isCompletable)
        .listRowInsets(LayoutMetrics.Insets.finalActionRow)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityHint(
          workout.isCompletable
            ? "Saves completed sets and opens your workout summary."
            : "Complete a set to finish this workout."
        )
      }
      .listSectionSeparator(.hidden)
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle(workout.displayName)
    .navigationBarTitleDisplayMode(.large)
    .navigationDestination(for: ActiveWorkoutExerciseRoute.self) { route in
      workoutExerciseDestination(for: route)
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Minimize Workout", systemImage: "chevron.down", action: onMinimize)
          .labelStyle(.iconOnly)
      }

      ToolbarItemGroup(placement: .topBarTrailing) {
        EditButton()

        Menu("More", systemImage: "ellipsis") {
          Button(
            "Save as New Template",
            systemImage: "rectangle.stack.badge.plus",
            action: presentTemplateEditor
          )
          .disabled(workout.orderedExercises.isEmpty)

          Button(
            "Discard Workout",
            systemImage: "trash",
            role: .destructive,
            action: requestDiscard
          )
        }
        .accessibilityHint(
          "Contains options for this workout."
        )
        .confirmationDialog(
          "Discard Workout?",
          isPresented: $isConfirmingDiscard,
          titleVisibility: .visible
        ) {
          Button("Discard Workout", role: .destructive, action: discardWorkout)
          Button("Continue Workout", role: .cancel) {}
        } message: {
          Text("This permanently deletes the workout and its sets.")
        }

        Button(
          "Add Exercise",
          systemImage: "plus",
          action: presentExercisePicker
        )
      }
    }
    .sheet(item: $presentedSheet) { sheet in
      switch sheet {
      case .exercisePicker:
        ExercisePickerView(
          onAdd: addExercises,
          errorMessage: activeWorkoutErrorMessage
        )
      case .template(let seed):
        AddWorkoutTemplateView(seed: seed)
      }
    }
    .alert("Workout Couldn’t Be Updated", isPresented: $isShowingError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage)
    }
    .onAppear(perform: prepareWorkout)
  }

  private func presentExercisePicker() {
    presentedSheet = .exercisePicker
  }

  private func addExercises(_ exercises: [Exercise]) throws {
    do {
      let store = TrainingDataStore(modelContext: modelContext)
      for exercise in exercises {
        try store.addExercise(exercise, to: workout)
      }
      try modelContext.save()
    } catch {
      modelContext.rollback()
      throw error
    }
  }

  private func presentTemplateEditor() {
    presentedSheet = .template(WorkoutTemplateSeed(workout: workout))
  }

  private func requestDiscard() {
    isConfirmingDiscard = true
  }

  private func finishWorkout() {
    let didComplete = performUpdate {
      try workout.complete()
    }

    if didComplete {
      onComplete(workout)
    }
  }

  private func discardWorkout() {
    let didDiscard = performUpdate {
      try TrainingDataStore(modelContext: modelContext).discard(workout)
    }

    if didDiscard {
      onDiscard()
    }
  }

  private func prepareWorkout() {
    performUpdate {
      try TrainingDataStore(modelContext: modelContext).prepareForEditing(workout)
    }
  }

  private func moveExercises(from offsets: IndexSet, to destination: Int) {
    var orderedExercises = workout.orderedExercises
    orderedExercises.move(fromOffsets: offsets, toOffset: destination)
    performUpdate {
      try TrainingDataStore(modelContext: modelContext).reorderExercises(
        in: workout,
        to: orderedExercises
      )
    }
  }

  private func removeExercises(
    at offsets: IndexSet,
    from exerciseSummaries: [ActiveWorkoutExerciseSummary]
  ) {
    let exerciseIDs = offsets.compactMap { index in
      exerciseSummaries.indices.contains(index)
        ? exerciseSummaries[index].id
        : nil
    }
    guard exerciseSummaries.count - exerciseIDs.count >= 1 else { return }

    performUpdate {
      let store = TrainingDataStore(modelContext: modelContext)
      for exerciseID in exerciseIDs {
        guard
          let workoutExercise = workout.workoutExercises.first(where: {
            $0.id == exerciseID
          })
        else { continue }
        try store.remove(workoutExercise, from: workout)
      }
    }
  }

  private func removeExercise(withID exerciseID: UUID) {
    guard workout.orderedExercises.count > 1 else { return }
    guard
      let workoutExercise = workout.workoutExercises.first(where: {
        $0.id == exerciseID
      })
    else { return }

    performUpdate {
      try TrainingDataStore(modelContext: modelContext).remove(
        workoutExercise,
        from: workout
      )
    }
  }

  @ViewBuilder
  private func workoutExerciseDestination(
    for route: ActiveWorkoutExerciseRoute
  ) -> some View {
    if let workoutExercise = workout.workoutExercises.first(where: {
      $0.id == route.exerciseID
    }) {
      ActiveWorkoutExerciseView(
        workoutExercise: workoutExercise,
        onNextExercise: showNextExercise,
        onReturnToWorkout: returnToWorkout
      )
      .id(workoutExercise.id)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Minimize Workout", systemImage: "chevron.down", action: onMinimize)
            .labelStyle(.iconOnly)
        }
      }
    } else {
      ContentUnavailableView {
        ContentUnavailableLogoLabel(title: "Exercise Unavailable")
      } description: {
        Text("This exercise is no longer part of the workout.")
      }
    }
  }

  private func showNextExercise(withID exerciseID: UUID) {
    guard workout.workoutExercises.contains(where: { $0.id == exerciseID }) else {
      return
    }

    withAnimation(reduceMotion ? nil : .default) {
      let route = ActiveWorkoutExerciseRoute(exerciseID: exerciseID)
      if navigationPath.isEmpty {
        navigationPath.append(route)
      } else {
        navigationPath[navigationPath.count - 1] = route
      }
    }
  }

  private func returnToWorkout() {
    withAnimation(reduceMotion ? nil : .default) {
      navigationPath.removeAll()
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

private enum ActiveWorkoutSheet: Identifiable {
  case exercisePicker
  case template(WorkoutTemplateSeed)

  var id: String {
    switch self {
    case .exercisePicker:
      "exercise-picker"
    case .template(let seed):
      "template-\(seed.id)"
    }
  }
}

private struct ActiveWorkoutHeader: View {
  let workout: Workout

  var body: some View {
    VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.small) {
      Text(
        workout.startedAt,
        format: .dateTime
          .weekday(.abbreviated)
          .month(.wide)
          .day()
          .hour()
          .minute()
      )
      .font(.headline)
      .foregroundStyle(.secondary)

      if let notes = workout.notes {
        Text(notes)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      ActiveWorkoutStats(workout: workout)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, LayoutMetrics.Spacing.small)
    .listRowSeparator(.hidden)
    .listRowBackground(Color.clear)
    .accessibilityElement(children: .combine)
  }
}

private struct ActiveWorkoutEmptyState: View {
  let addExercise: () -> Void

  var body: some View {
    Section {
      ContentUnavailableView {
        ContentUnavailableLogoLabel(title: "No Exercises")
      } description: {
        Text("Add an exercise to start logging this workout.")
      }
      .listRowSeparator(.hidden)
      .listRowBackground(Color.clear)

      Button("Add Exercise", systemImage: "plus", action: addExercise)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.pink)
        .fixedSize()
        .frame(maxWidth: .infinity)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
  }
}

func activeWorkoutErrorMessage(for error: Error) -> String {
  guard let modelError = error as? WorkoutModelError else {
    return error.localizedDescription
  }

  return switch modelError {
  case .cannotRemoveLastSet:
    "Each exercise needs at least one set."
  case .exerciseIsArchived:
    "This exercise is no longer available."
  case .invalidReps:
    "Enter at least one repetition for every set before saving the workout."
  case .missingExercise:
    "Remove unavailable exercises before saving the workout."
  case .missingWeight:
    "Enter a weight for every weighted set before saving the workout."
  case .missingWeightUnit:
    "Choose a weight unit for every weighted set before saving the workout."
  case .workoutAlreadyCompleted:
    "This workout has already ended."
  case .workoutHasNoSets:
    "Complete at least one set before saving the workout, or discard it instead."
  case .workoutIsNotInProgress:
    "Only an active workout can be edited."
  default:
    "The workout couldn’t be updated."
  }
}

#Preview("Active Workout") {
  ActiveWorkoutView(
    workout: try! Workout(
      name: "Push Day",
      notes: "Chest and shoulders",
      startedAt: .now.addingTimeInterval(-3_725)
    ),
    navigationPath: .constant([]),
    onComplete: { _ in },
    onDiscard: {},
    onMinimize: {}
  )
  .modelContainer(for: BurthenSchema.models, inMemory: true)
}
