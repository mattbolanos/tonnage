//
//  ExerciseSetPicker.swift
//  Burthen
//

import SwiftData
import SwiftUI

struct ExerciseSetPicker: View {
  private static let persistenceDelay = Duration.milliseconds(300)

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let exerciseSet: ExerciseSet
  let setNumber: Int
  let weightUnit: WeightUnit

  @State private var kind: ExerciseSetKind
  @State private var repetitions: Int
  @State private var wholeWeight: Int
  @State private var usesHalfWeight: Bool
  @State private var isConfirmingStartingWeight = false
  @State private var startingWeightConfirmation: String?
  @State private var startingWeightSaveCount = 0
  @State private var hasPendingChanges = false
  @State private var persistenceTask: Task<Void, Never>?
  @State private var isShowingError = false
  @State private var errorMessage = ""

  init(
    exerciseSet: ExerciseSet,
    setNumber: Int,
    weightUnit: WeightUnit
  ) {
    self.exerciseSet = exerciseSet
    self.setNumber = setNumber
    self.weightUnit = weightUnit

    let weight = NSDecimalNumber(decimal: exerciseSet.weight ?? .zero).doubleValue
    let halfSteps = min(
      max(Int((weight * 2).rounded()), 0),
      ExerciseSetPickerControls.wholeWeightRange.upperBound * 2
    )

    _kind = State(initialValue: exerciseSet.kind)
    _repetitions = State(
      initialValue: min(max(exerciseSet.reps, 1), ExerciseSetPickerControls.repetitionRange.upperBound)
    )
    _wholeWeight = State(initialValue: halfSteps / 2)
    _usesHalfWeight = State(initialValue: !halfSteps.isMultiple(of: 2))
  }

  var body: some View {
    NavigationStack {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          ExerciseSetAccessibilityForm(
            kind: $kind,
            repetitions: $repetitions,
            wholeWeight: $wholeWeight,
            usesHalfWeight: $usesHalfWeight,
            weightUnit: weightUnit,
            repetitionMode: exerciseSet.repetitionMode,
            confirmation: startingWeightConfirmation
          )
        } else {
          ScrollView {
            ExerciseSetPickerControls(
              kind: $kind,
              repetitions: $repetitions,
              wholeWeight: $wholeWeight,
              usesHalfWeight: $usesHalfWeight,
              weightUnit: weightUnit,
              repetitionMode: exerciseSet.repetitionMode
            )
            .padding(.horizontal, LayoutMetrics.Padding.horizontalContent)
            .padding(.vertical, LayoutMetrics.Spacing.small)
          }
          .scrollBounceBehavior(.basedOnSize)
        }
      }
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: LayoutMetrics.Spacing.small) {
          if let startingWeightConfirmation, !dynamicTypeSize.isAccessibilitySize {
            Label(startingWeightConfirmation, systemImage: "checkmark.circle")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Button(action: finish) {
            Text("Done")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .accessibilityHint("Saves changes to this set and closes the editor.")
        }
        .padding(.horizontal, LayoutMetrics.Padding.horizontalContent)
        .padding(.vertical, LayoutMetrics.Spacing.small)
        .background {
          if dynamicTypeSize.isAccessibilitySize {
            Rectangle()
              .fill(.background)
              .ignoresSafeArea(.container, edges: .bottom)
          }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: startingWeightConfirmation)
        .sensoryFeedback(.success, trigger: startingWeightSaveCount)
      }
      .navigationTitle("Set \(setNumber)")
      .navigationBarTitleDisplayMode(.inline)
      .onChange(of: kind, scheduleSave)
      .onChange(of: repetitions, scheduleSave)
      .onChange(of: wholeWeight, updateWholeWeight)
      .onChange(of: usesHalfWeight, updateHalfWeight)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu("Set Options", systemImage: "ellipsis") {
            Button(startingWeightMenuTitle, action: confirmStartingWeight)
              .disabled(exerciseSet.workoutExercise?.exercise == nil)
          }
          .labelStyle(.iconOnly)
          .confirmationDialog(
            startingWeightDialogTitle,
            isPresented: $isConfirmingStartingWeight,
            titleVisibility: .visible
          ) {
            Button(startingWeightActionTitle, action: setStartingWeight)
            Button("Cancel", role: .cancel) {}
          } message: {
            Text(startingWeightScopeMessage)
          }
        }
      }
      .alert("Set Couldn’t Be Updated", isPresented: $isShowingError) {
      } message: {
        Text(errorMessage)
      }
    }
    .presentationDetents(
      dynamicTypeSize.isAccessibilitySize || exerciseSet.repetitionMode == .perSide
        ? [.large] : [.medium, .large]
    )
    .presentationDragIndicator(.visible)
    .interactiveDismissDisabled(hasPendingChanges || isShowingError)
    .onDisappear(perform: savePendingChanges)
  }

  private var selectedWeight: Decimal? {
    let halfSteps = wholeWeight * 2 + (usesHalfWeight ? 1 : 0)
    return halfSteps == 0 ? nil : Decimal(halfSteps) / 2
  }

  private var followingSets: [ExerciseSet] {
    exerciseSet.workoutExercise?.followingSets(after: exerciseSet) ?? []
  }

  private var startingWeightMenuTitle: String {
    selectedWeight == nil
      ? String(localized: "Clear Starting Weight…")
      : String(localized: "Set as Starting Weight…")
  }

  private var startingWeightDialogTitle: String {
    selectedWeight == nil
      ? String(localized: "Clear Starting Weight?")
      : String(localized: "Save Starting Weight?")
  }

  private var startingWeightActionTitle: String {
    if selectedWeight == nil {
      return followingSets.isEmpty
        ? String(localized: "Clear Starting Weight")
        : String(localized: "Clear Starting and Set Weights")
    }

    return followingSets.isEmpty
      ? String(localized: "Save Starting Weight")
      : String(localized: "Save and Update Sets")
  }

  private var startingWeightScopeMessage: String {
    let exerciseName = exerciseSet.workoutExercise?.exercise?.name ?? "this exercise"
    let preferenceMessage: String
    if let selectedWeight {
      let weight = "\(selectedWeight.formatted()) \(weightUnit.displayAbbreviation)"
      preferenceMessage = String(
        localized: "Save \(weight) as the starting weight for \(exerciseName), used when there’s no completed workout history."
      )
    } else {
      preferenceMessage = String(localized: "Clear the saved starting weight for \(exerciseName).")
    }

    guard !followingSets.isEmpty else { return preferenceMessage }

    let followingMessage: String
    if selectedWeight == nil && followingSets.contains(where: \.isCompleted) {
      followingMessage = String(
        localized: "This also clears the weight of every set after this one in this exercise, including completed sets."
      )
    } else if selectedWeight == nil {
      followingMessage = String(
        localized: "This also clears the weight of every set after this one in this exercise."
      )
    } else if followingSets.contains(where: \.isCompleted) {
      followingMessage = String(
        localized: "This also replaces the weight of every set after this one in this exercise, including completed sets."
      )
    } else {
      followingMessage = String(
        localized: "This also replaces the weight of every set after this one in this exercise."
      )
    }
    return "\(preferenceMessage)\n\n\(followingMessage)"
  }

  private func confirmStartingWeight() {
    isConfirmingStartingWeight = true
  }

  private func setStartingWeight() {
    persistenceTask?.cancel()
    persistenceTask = nil
    hasPendingChanges = true
    applyChanges()

    do {
      try TrainingDataStore(modelContext: modelContext)
        .saveStartingWeight(from: exerciseSet)
      hasPendingChanges = false
      let confirmation: String
      if let selectedWeight {
        let weight = "\(selectedWeight.formatted()) \(weightUnit.displayAbbreviation)"
        confirmation = followingSets.isEmpty
          ? String(localized: "\(weight) saved as this exercise’s starting weight.")
          : String(localized: "\(weight) saved. Following sets updated.")
      } else {
        confirmation = followingSets.isEmpty
          ? String(localized: "Starting weight cleared.")
          : String(localized: "Starting weight and following set weights cleared.")
      }
      startingWeightConfirmation = confirmation
      startingWeightSaveCount += 1
      AccessibilityNotification.Announcement(confirmation).post()
    } catch {
      startingWeightConfirmation = nil
      errorMessage = activeWorkoutErrorMessage(for: error)
      isShowingError = true
    }
  }

  private func enforceWeightLimit() {
    if wholeWeight == ExerciseSetPickerControls.wholeWeightRange.upperBound {
      usesHalfWeight = false
    }
  }

  private func updateWholeWeight() {
    enforceWeightLimit()
    scheduleSave()
  }

  private func updateHalfWeight() {
    // Publish discrete taps immediately; only persistence waits for the debounce.
    applyChanges()
    scheduleSave()
  }

  private func scheduleSave() {
    startingWeightConfirmation = nil
    hasPendingChanges = true
    persistenceTask?.cancel()
    persistenceTask = Task {
      try? await Task.sleep(for: Self.persistenceDelay)
      guard !Task.isCancelled else { return }
      savePendingChanges()
    }
  }

  private func applyChanges() {
    exerciseSet.kind = kind
    exerciseSet.reps = repetitions
    exerciseSet.weight = selectedWeight
    exerciseSet.weightUnit = selectedWeight == nil ? nil : weightUnit
    exerciseSet.workoutExercise?.workout?.updatedAt = .now
  }

  private func savePendingChanges() {
    persistenceTask?.cancel()
    persistenceTask = nil

    guard hasPendingChanges else { return }

    applyChanges()

    do {
      try modelContext.save()
      hasPendingChanges = false
    } catch {
      errorMessage = activeWorkoutErrorMessage(for: error)
      isShowingError = true
    }
  }

  private func finish() {
    savePendingChanges()
    guard !hasPendingChanges else { return }
    dismiss()
  }
}
