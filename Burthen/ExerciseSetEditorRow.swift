//
//  ExerciseSetEditorRow.swift
//  Burthen
//

import SwiftUI

enum ExerciseSetDisplayMode: Hashable {
  case repetitionsAndWeight
  case setLoad
}

struct ExerciseSetEditorRow: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ScaledMetric(relativeTo: .body)
  private var setNumberColumnWidth = LayoutMetrics.Size.setNumberColumn

  let exerciseSet: ExerciseSet
  let setNumber: Int
  let weightUnit: WeightUnit
  let requiresWeight: Bool
  let displayMode: ExerciseSetDisplayMode
  let canDelete: Bool
  let edit: (ExerciseSet) -> Void
  let setCompletion: (Bool, ExerciseSet) -> Void
  let remove: (ExerciseSet) -> Void

  var body: some View {
    HStack(spacing: LayoutMetrics.Spacing.medium) {
      Button(action: editSet) {
        HStack(alignment: .firstTextBaseline, spacing: LayoutMetrics.Spacing.medium) {
          Text(setNumber, format: .number)
            .font(.body.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(
              width: setNumberColumnWidth,
              alignment: .leading
            )

          switch displayMode {
          case .repetitionsAndWeight:
            setSummary
              .font(.body.weight(.semibold))
              .monospacedDigit()
              .foregroundStyle(.primary)
          case .setLoad:
            TrainingLoadText(load: setLoad, emphasis: .standard)
              .font(.body.weight(.semibold))
          }

          Spacer(minLength: LayoutMetrics.Spacing.small)

          if exerciseSet.kind == .warmup {
            Text("Warm-up")
              .font(.body.weight(.medium))
              .foregroundStyle(.orange)
              .lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .opacity(exerciseSet.isCompleted ? 0.5 : 1)
      .accessibilityLabel("Set \(setNumber)")
      .accessibilityValue(accessibilityValue)
      .accessibilityHint("Opens the set editor")
      .accessibilityInputLabels(["Edit Set \(setNumber)", "Set \(setNumber)"])

      Button(action: toggleCompletion) {
        Label(completionButtonLabel, systemImage: completionSystemImage)
          .labelStyle(.iconOnly)
          .font(.title3)
          .foregroundStyle(
            exerciseSet.isCompleted ? Color.accentColor : Color.secondary
          )
          .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
          .frame(
            width: LayoutMetrics.Size.setCompletionControl,
            height: LayoutMetrics.Size.setCompletionControl
          )
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityHint(
        exerciseSet.isCompleted
          ? "Removes this set from training load."
          : "Adds this set to training load."
      )
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if canDelete {
        Button("Delete Set", systemImage: "trash", role: .destructive, action: removeSet)
          .labelStyle(.iconOnly)
      }
    }
  }

  private var weightedRepetitions: String {
    exerciseSet.repetitionMode == .perSide
      ? exerciseSet.repetitionMode.description(for: exerciseSet.reps, abbreviated: true)
      : "\(exerciseSet.reps)"
  }

  private var setSummary: Text {
    guard requiresWeight || exerciseSet.weight != nil else {
      return Text("\(exerciseSet.repetitionMode.description(for: exerciseSet.reps, abbreviated: true))")
    }

    guard let weight = exerciseSet.weight else {
      return Text("\(weightedRepetitions) x — \(weightUnit.displayAbbreviation)")
    }

    return Text(
      "\(weightedRepetitions) x \(weight, format: .number.precision(.fractionLength(0...1))) \(weightUnit.displayAbbreviation)"
    )
  }

  private var setLoad: VolumeLoad? {
    VolumeLoad.forSet(
      kind: exerciseSet.kind,
      repetitions: exerciseSet.reps,
      repetitionMode: exerciseSet.repetitionMode,
      weight: exerciseSet.weight,
      unit: exerciseSet.weightUnit ?? weightUnit
    )
  }

  private var accessibilityValue: String {
    let completion = exerciseSet.isCompleted ? "Completed" : "Not completed"
    let type = exerciseSet.kind == .warmup
      ? "Warm-up set, excluded from training load"
      : "Working set"

    let loadDescription = setLoad.map { ", set load \($0.accessibilityText)" } ?? ""

    guard requiresWeight || exerciseSet.weight != nil else {
      return "\(completion), \(type), \(exerciseSet.repetitionMode.description(for: exerciseSet.reps))\(loadDescription)"
    }

    guard let weight = exerciseSet.weight else {
      return "\(completion), \(type), \(exerciseSet.repetitionMode.description(for: exerciseSet.reps)), no weight"
    }

    return "\(completion), \(type), \(exerciseSet.repetitionMode.description(for: exerciseSet.reps)), \(weight) \(weightUnit.spokenName)\(loadDescription)"
  }

  private func editSet() {
    edit(exerciseSet)
  }

  private var completionButtonLabel: String {
    if exerciseSet.repetitionMode == .perSide {
      return exerciseSet.isCompleted ? "Mark Both Sides Incomplete" : "Complete Both Sides"
    }
    return exerciseSet.isCompleted ? "Mark Set Incomplete" : "Complete Set"
  }

  private var completionSystemImage: String {
    exerciseSet.isCompleted ? "checkmark.circle.fill" : "circle"
  }

  private func toggleCompletion() {
    setCompletion(!exerciseSet.isCompleted, exerciseSet)
  }

  private func removeSet() {
    remove(exerciseSet)
  }
}
