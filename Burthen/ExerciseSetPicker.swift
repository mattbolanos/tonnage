//
//  ExerciseSetPicker.swift
//  Burthen
//

import SwiftData
import SwiftUI

struct ExerciseSetPicker: View {
  private static let repetitionRange = 1...49
  private static let wholeWeightRange = 0...399
  private static let persistenceDelay = Duration.milliseconds(300)

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let exerciseSet: ExerciseSet
  let setNumber: Int
  let weightUnit: WeightUnit

  @State private var kind: ExerciseSetKind
  @State private var repetitions: Int
  @State private var wholeWeight: Int
  @State private var usesHalfWeight: Bool
  @State private var startingWeightConfirmation: String?
  @State private var startingWeightSaveCount = 0
  @State private var hasPendingChanges = false
  @State private var persistenceTask: Task<Void, Never>?
  @State private var isShowingError = false
  @State private var errorMessage = ""

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @ScaledMetric(relativeTo: .title2)
  private var unitSpacing = LayoutMetrics.Spacing.small

  @ScaledMetric(relativeTo: .title2)
  private var wheelHeight = LayoutMetrics.Size.wheelPicker

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
      Self.wholeWeightRange.upperBound * 2
    )

    _kind = State(initialValue: exerciseSet.kind)
    _repetitions = State(
      initialValue: min(max(exerciseSet.reps, 1), Self.repetitionRange.upperBound)
    )
    _wholeWeight = State(initialValue: halfSteps / 2)
    _usesHalfWeight = State(initialValue: !halfSteps.isMultiple(of: 2))
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: LayoutMetrics.Spacing.medium) {
        VStack(spacing: LayoutMetrics.Spacing.small) {
          Picker("Set Type", selection: $kind) {
            Text("Working")
              .tag(ExerciseSetKind.working)
            Text("Warm-up")
              .tag(ExerciseSetKind.warmup)
          }
          .pickerStyle(.segmented)

        }
        .padding(.bottom, LayoutMetrics.Spacing.extraSmall)

        HStack(spacing: LayoutMetrics.Spacing.large) {
          ZStack {
            Picker("Repetitions", selection: $repetitions) {
              ForEach(Self.repetitionRange, id: \.self) { repetition in
                HStack(spacing: unitSpacing) {
                  ZStack(alignment: .trailing) {
                    Text(Self.repetitionRange.upperBound, format: .number)
                      .hidden()
                    Text(repetition, format: .number)
                  }
                  Text("reps")
                    .hidden()
                }
                .fixedSize(horizontal: true, vertical: false)
                .tag(repetition)
              }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .accessibilityValue("\(repetitions) repetitions")

            HStack(spacing: unitSpacing) {
              Text(Self.repetitionRange.upperBound, format: .number)
                .hidden()
              Text("reps")
            }
            .fixedSize(horizontal: true, vertical: false)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
          }
          .font(.title2)
          .monospacedDigit()
          .frame(maxWidth: .infinity)
          .frame(height: wheelHeight)
          .clipped()

          ZStack {
            Picker("Weight", selection: $wholeWeight) {
              ForEach(Self.wholeWeightRange, id: \.self) { weight in
                HStack(spacing: unitSpacing) {
                  HStack(spacing: 0) {
                    ZStack(alignment: .trailing) {
                      Text(Self.wholeWeightRange.upperBound, format: .number)
                        .hidden()
                      Text(weight, format: .number)
                    }
                    // Reserve the fraction width so toggling does not relayout every wheel row.
                    Text(".5")
                      .hidden()
                  }
                  Text(weightUnit.displayAbbreviation)
                    .hidden()
                }
                .fixedSize(horizontal: true, vertical: false)
                .tag(weight)
              }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .accessibilityValue(weightAccessibilityValue)

            HStack(spacing: unitSpacing) {
              HStack(spacing: 0) {
                Text(Self.wholeWeightRange.upperBound, format: .number)
                  .hidden()
                Text(".5")
                  .opacity(usesHalfWeight ? 1 : 0)
              }
              Text(weightUnit.displayAbbreviation)
            }
            .fixedSize(horizontal: true, vertical: false)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
          }
          .font(.title2)
          .monospacedDigit()
          .frame(maxWidth: .infinity)
          .frame(height: wheelHeight)
          .clipped()
        }

        HStack(spacing: LayoutMetrics.Spacing.large) {
          Spacer()
            .frame(maxWidth: .infinity)

          Toggle(isOn: $usesHalfWeight) {
            Text("\(usesHalfWeight ? "−" : "+") ½ \(weightUnit.displayAbbreviation)")
              .frame(maxWidth: .infinity)
          }
          .toggleStyle(.button)
          .buttonStyle(.bordered)
          .accessibilityLabel("Half \(weightUnit.spokenName)")
          .disabled(wholeWeight == Self.wholeWeightRange.upperBound)
          .frame(maxWidth: .infinity)
        }

        Spacer(minLength: 0)

        VStack(spacing: LayoutMetrics.Spacing.small) {
          Button(action: setStartingWeight) {
            Text(
              startingWeightConfirmation == nil ? "Set as Starting Weight" : "Starting Weight Saved"
            )
            .frame(maxWidth: .infinity)
            .contentTransition(.opacity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .disabled(exerciseSet.workoutExercise?.exercise == nil)
          .accessibilityHint(
            "Saves this exercise’s starting weight and copies it to subsequent sets.")
        }
        .padding(.top, LayoutMetrics.Spacing.medium)
        .padding(.bottom, LayoutMetrics.Spacing.large)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: startingWeightConfirmation)
        .sensoryFeedback(.success, trigger: startingWeightSaveCount)
      }
      .padding(.horizontal, LayoutMetrics.Padding.horizontalContent)
      .navigationTitle("Set \(setNumber)")
      .navigationBarTitleDisplayMode(.inline)
      .onChange(of: kind, scheduleSave)
      .onChange(of: repetitions, scheduleSave)
      .onChange(of: wholeWeight, updateWholeWeight)
      .onChange(of: usesHalfWeight, updateHalfWeight)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", action: finish)
        }
      }
      .alert("Set Couldn’t Be Updated", isPresented: $isShowingError) {
      } message: {
        Text(errorMessage)
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .onDisappear(perform: savePendingChanges)
  }

  private var weightAccessibilityValue: String {
    let halfSteps = wholeWeight * 2 + (usesHalfWeight ? 1 : 0)
    let weight = Decimal(halfSteps) / 2
    return "\(weight) \(weightUnit.spokenName)"
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
      let weight =
        exerciseSet.weight.map {
          "\($0.formatted()) \(weightUnit.displayAbbreviation)"
        } ?? "No added weight"
      let hasFollowingSets =
        !(exerciseSet.workoutExercise?
        .followingSets(after: exerciseSet).isEmpty ?? true)
      let confirmation =
        hasFollowingSets
        ? "\(weight) saved. Subsequent sets updated."
        : "\(weight) saved as this exercise’s starting weight."
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
    if wholeWeight == Self.wholeWeightRange.upperBound {
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
    let halfSteps = wholeWeight * 2 + (usesHalfWeight ? 1 : 0)

    exerciseSet.kind = kind
    exerciseSet.reps = repetitions
    exerciseSet.weight = halfSteps == 0 ? nil : Decimal(halfSteps) / 2
    exerciseSet.weightUnit = halfSteps == 0 ? nil : weightUnit
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
