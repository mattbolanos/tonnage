//
//  WorkoutTemplateEditorView.swift
//  Burthen
//

import SwiftData
import SwiftUI

struct WorkoutTemplateSeed: Identifiable {
  let id = UUID()
  let name: String
  let notes: String?
  let exercisePlans: [TemplateExercisePlan]

  init(
    name: String = "",
    notes: String? = nil,
    exercisePlans: [TemplateExercisePlan] = []
  ) {
    self.name = name
    self.notes = notes
    self.exercisePlans = exercisePlans
  }

  init(exercises: [Exercise]) {
    self.init(
      exercisePlans: exercises.map { exercise in
        TemplateExercisePlan(
          exercise: exercise,
          plannedWorkingSetCount: TrainingDefaults.workingSetCount
        )
      }
    )
  }

  init(workout: Workout) {
    self.init(
      name: workout.sourceTemplate == nil ? workout.name ?? "" : "",
      notes: workout.notes,
      exercisePlans: workout.templateExercisePlans
    )
  }
}

struct AddWorkoutTemplateView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let offersWorkoutStart: Bool

  @State private var draft: WorkoutTemplateDraft
  @State private var startsWorkoutAfterCreating = true
  @State private var isShowingError = false
  @State private var dismissAfterError = false
  @State private var errorTitle = ""
  @State private var errorMessage = ""

  init(
    seed: WorkoutTemplateSeed = WorkoutTemplateSeed(),
    offersWorkoutStart: Bool = false
  ) {
    self.offersWorkoutStart = offersWorkoutStart
    _draft = State(initialValue: WorkoutTemplateDraft(seed: seed))
  }

  var body: some View {
    NavigationStack {
      WorkoutTemplateForm(
        draft: $draft,
        startsWorkoutAfterCreating: offersWorkoutStart
          ? $startsWorkoutAfterCreating
          : nil
      )
        .navigationTitle("New Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: dismiss.callAsFunction)
          }
          ToolbarItemGroup(placement: .topBarTrailing) {
            Button(
              offersWorkoutStart ? "Create" : "Add",
              action: createTemplate
            )
            .disabled(!draft.isValid)
          }
        }
        .alert(errorTitle, isPresented: $isShowingError) {
          Button("OK", role: .cancel, action: handleErrorDismissal)
        } message: {
          Text(errorMessage)
        }
    }
  }

  private func createTemplate() {
    do {
      let store = TrainingDataStore(modelContext: modelContext)
      let template = try store.createTemplate(
        name: draft.normalizedName,
        notes: draft.normalizedNotes,
        exercises: draft.exercisePlans
      )
      try modelContext.save()

      guard offersWorkoutStart, startsWorkoutAfterCreating else {
        dismiss()
        return
      }

      startWorkout(from: template)
    } catch {
      modelContext.rollback()
      dismissAfterError = false
      errorTitle = offersWorkoutStart
        ? "Template Couldn’t Be Created"
        : "Template Couldn’t Be Added"
      errorMessage = templateErrorMessage(for: error)
      isShowingError = true
    }
  }

  private func startWorkout(from template: WorkoutTemplate) {
    do {
      _ = try TrainingDataStore(modelContext: modelContext).startWorkout(
        from: template
      )
      try modelContext.save()
      dismiss()
    } catch {
      modelContext.rollback()
      dismissAfterError = true
      errorTitle = "Workout Couldn’t Be Started"
      errorMessage = """
        The template was created, but the workout couldn’t be started. \
        \(templateErrorMessage(for: error))
        """
      isShowingError = true
    }
  }

  private func handleErrorDismissal() {
    guard dismissAfterError else { return }
    dismissAfterError = false
    dismiss()
  }
}

struct EditWorkoutTemplateView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let template: WorkoutTemplate

  @State private var draft: WorkoutTemplateDraft
  @State private var isShowingError = false
  @State private var errorMessage = ""

  init(template: WorkoutTemplate) {
    self.template = template
    _draft = State(initialValue: WorkoutTemplateDraft(template: template))
  }

  private var canSave: Bool {
    draft.isValid && draft.signature != template.editorSignature
  }

  var body: some View {
    WorkoutTemplateForm(
      draft: $draft,
      showsArchivedNotice: template.isArchived
    )
    .navigationTitle("Edit Template")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        EditButton()
        Button("Save", action: save)
          .disabled(!canSave)
      }
    }
    .alert("Template Couldn’t Be Updated", isPresented: $isShowingError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage)
    }
  }

  private func save() {
    do {
      try TrainingDataStore(modelContext: modelContext).updateTemplate(
        template,
        name: draft.normalizedName,
        notes: draft.normalizedNotes,
        exercises: draft.exercisePlans
      )
      try modelContext.save()
      dismiss()
    } catch {
      errorMessage = templateErrorMessage(for: error)
      isShowingError = true
    }
  }
}

private struct WorkoutTemplateForm: View {
  @Binding var draft: WorkoutTemplateDraft
  let startsWorkoutAfterCreating: Binding<Bool>?
  let showsArchivedNotice: Bool

  @State private var isSelectingExercises = false

  init(
    draft: Binding<WorkoutTemplateDraft>,
    startsWorkoutAfterCreating: Binding<Bool>? = nil,
    showsArchivedNotice: Bool = false
  ) {
    _draft = draft
    self.startsWorkoutAfterCreating = startsWorkoutAfterCreating
    self.showsArchivedNotice = showsArchivedNotice
  }

  var body: some View {
    let duplicateExerciseIDs = draft.duplicateExerciseIDs

    Form {
      if showsArchivedNotice {
        Section {
          Label("Archived", systemImage: "archivebox")
            .foregroundStyle(.secondary)
        } footer: {
          Text("Restore this template from the template list to use it for new workouts.")
        }
      }

      Section {
        TextField("Name", text: $draft.name)
          .textInputAutocapitalization(.words)

        TextField("Notes", text: $draft.notes, axis: .vertical)
          .lineLimit(2...5)

        if let startsWorkoutAfterCreating {
          Toggle("Start After Creating", isOn: startsWorkoutAfterCreating)
            .accessibilityHint(
              "Starts a workout with this template after it’s created."
            )
        }
      } header: {
        SectionHeader("Template")
      }

      Section {
        if !draft.exercises.isEmpty {
          ForEach($draft.exercises) { $exercise in
            TemplateExerciseEditorRow(
              item: $exercise,
              isRepeated: duplicateExerciseIDs.contains(exercise.exercise.id)
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button(
                "Delete Exercise",
                systemImage: "trash",
                role: .destructive
              ) {
                removeExercise(exercise)
              }
              .labelStyle(.iconOnly)
            }
          }
          .onDelete(perform: removeExercises)
          .onMove(perform: moveExercises)
        }

        Button(action: selectExercises) {
          Label("Add Exercises", systemImage: "plus")
            .foregroundStyle(.pink)
        }
      } header: {
        SectionHeader("Exercises")
      } footer: {
        if draft.exercises.isEmpty {
          Text("Add exercises in the order you want to perform them.")
        } else if draft.hasUnavailableExercises && draft.hasDuplicateExercises {
          Text("Remove archived and repeated exercises before saving this template.")
            .foregroundStyle(.orange)
        } else if draft.hasUnavailableExercises {
          Text("Remove archived exercises before saving this template.")
            .foregroundStyle(.orange)
        } else if draft.hasDuplicateExercises {
          Text("Remove repeated exercises before saving this template.")
            .foregroundStyle(.orange)
        } else {
          Text("Templates save exercise order and working set counts, not weights or reps.")
        }
      }
    }
    .sheet(isPresented: $isSelectingExercises) {
      ExercisePickerView(
        existingExerciseIDs: Set(draft.exercises.map { $0.exercise.id }),
        onAdd: appendExercises
      )
    }
  }

  private func selectExercises() {
    isSelectingExercises = true
  }

  private func appendExercises(_ exercises: [Exercise]) {
    draft.exercises.append(contentsOf: exercises.map {
      TemplateExerciseDraft(exercise: $0)
    })
  }

  private func removeExercises(at offsets: IndexSet) {
    draft.exercises.remove(atOffsets: offsets)
  }

  private func removeExercise(_ exercise: TemplateExerciseDraft) {
    draft.exercises.removeAll { $0.id == exercise.id }
  }

  private func moveExercises(from offsets: IndexSet, to destination: Int) {
    draft.exercises.move(fromOffsets: offsets, toOffset: destination)
  }
}

private struct TemplateExerciseEditorRow: View {
  @Binding var item: TemplateExerciseDraft
  let isRepeated: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.small) {
      HStack {
        Text(item.exercise.name)
        Spacer()

        VStack(alignment: .trailing, spacing: LayoutMetrics.Spacing.extraSmall) {
          if item.exercise.isArchived {
            Label("Archived", systemImage: "archivebox")
          }
          if isRepeated {
            Label("Repeated", systemImage: "exclamationmark.triangle")
          }
        }
        .font(.caption)
        .foregroundStyle(.orange)
      }

      Stepper(
        "Working Sets: \(item.plannedWorkingSetCount)",
        value: $item.plannedWorkingSetCount,
        in: 1...20
      )
      .font(.subheadline)
    }
  }
}

private struct WorkoutTemplateDraft {
  var name = ""
  var notes = ""
  var exercises: [TemplateExerciseDraft] = []

  init() {}

  init(seed: WorkoutTemplateSeed) {
    name = seed.name
    notes = seed.notes ?? ""
    exercises = seed.exercisePlans.map { plan in
      TemplateExerciseDraft(
        exercise: plan.exercise,
        plannedWorkingSetCount: plan.plannedWorkingSetCount
          ?? TrainingDefaults.workingSetCount
      )
    }
  }

  init(template: WorkoutTemplate) {
    name = template.name
    notes = template.notes ?? ""
    exercises = template.orderedExercises.compactMap { templateExercise in
      guard let exercise = templateExercise.exercise else { return nil }
      return TemplateExerciseDraft(
        id: templateExercise.id,
        exercise: exercise,
        plannedWorkingSetCount: templateExercise.plannedWorkingSetCount
          ?? TrainingDefaults.workingSetCount
      )
    }
  }

  var normalizedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var normalizedNotes: String? {
    let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalizedNotes.isEmpty ? nil : normalizedNotes
  }

  var hasUnavailableExercises: Bool {
    exercises.contains { $0.exercise.isArchived }
  }

  var duplicateExerciseIDs: Set<UUID> {
    var seenExerciseIDs = Set<UUID>()
    var duplicateExerciseIDs = Set<UUID>()

    for exercise in exercises {
      if !seenExerciseIDs.insert(exercise.exercise.id).inserted {
        duplicateExerciseIDs.insert(exercise.exercise.id)
      }
    }

    return duplicateExerciseIDs
  }

  var hasDuplicateExercises: Bool {
    !duplicateExerciseIDs.isEmpty
  }

  var isValid: Bool {
    !normalizedName.isEmpty
      && !exercises.isEmpty
      && !hasUnavailableExercises
      && !hasDuplicateExercises
  }

  var exercisePlans: [TemplateExercisePlan] {
    exercises.map { exercise in
      TemplateExercisePlan(
        exercise: exercise.exercise,
        plannedWorkingSetCount: exercise.plannedWorkingSetCount
      )
    }
  }

  var signature: WorkoutTemplateEditorSignature {
    WorkoutTemplateEditorSignature(
      name: normalizedName,
      notes: normalizedNotes,
      exercises: exercises.map { exercise in
        WorkoutTemplateExerciseSignature(
          exerciseID: exercise.exercise.id,
          plannedWorkingSetCount: exercise.plannedWorkingSetCount
        )
      }
    )
  }
}

private struct TemplateExerciseDraft: Identifiable {
  let id: UUID
  let exercise: Exercise
  var plannedWorkingSetCount: Int

  init(
    id: UUID = UUID(),
    exercise: Exercise,
    plannedWorkingSetCount: Int = TrainingDefaults.workingSetCount
  ) {
    self.id = id
    self.exercise = exercise
    self.plannedWorkingSetCount = plannedWorkingSetCount
  }
}

private struct WorkoutTemplateEditorSignature: Equatable {
  let name: String
  let notes: String?
  let exercises: [WorkoutTemplateExerciseSignature]
}

private struct WorkoutTemplateExerciseSignature: Equatable {
  let exerciseID: UUID
  let plannedWorkingSetCount: Int
}

extension WorkoutTemplate {
  fileprivate var editorSignature: WorkoutTemplateEditorSignature {
    WorkoutTemplateEditorSignature(
      name: name,
      notes: notes,
      exercises: orderedExercises.compactMap { templateExercise in
        guard let exercise = templateExercise.exercise else { return nil }
        return WorkoutTemplateExerciseSignature(
          exerciseID: exercise.id,
          plannedWorkingSetCount: templateExercise.plannedWorkingSetCount
            ?? TrainingDefaults.workingSetCount
        )
      }
    )
  }
}

#Preview("New Template") {
  AddWorkoutTemplateView()
    .modelContainer(for: BurthenSchema.models, inMemory: true)
}
