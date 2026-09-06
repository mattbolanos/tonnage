//
//  CompletedWorkoutSetRow.swift
//  Burthen
//

import SwiftUI

struct CompletedWorkoutSetRow: View {
  @ScaledMetric(relativeTo: .subheadline)
  private var setNumberColumnWidth = LayoutMetrics.Size.setNumberColumn

  let exerciseSet: ExerciseSet
  let setNumber: Int

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: LayoutMetrics.Spacing.medium) {
      Text(setNumber, format: .number)
        .font(.subheadline.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .frame(
          width: setNumberColumnWidth,
          alignment: .leading
        )

      VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.extraSmall) {
        setSummary
          .font(.subheadline.weight(.semibold))
          .monospacedDigit()
          .foregroundStyle(.primary)

        if exerciseSet.kind == .warmup {
          Text("Warm-up")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: LayoutMetrics.Spacing.small)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Set \(setNumber)")
    .accessibilityValue(accessibilityValue)
  }

  private var weightedRepetitions: String {
    exerciseSet.repetitionMode == .perSide
      ? exerciseSet.repetitionMode.description(for: exerciseSet.reps, abbreviated: true)
      : "\(exerciseSet.reps)"
  }

  private var setSummary: Text {
    guard let weight = exerciseSet.weight else {
      return Text("\(exerciseSet.repetitionMode.description(for: exerciseSet.reps, abbreviated: true))")
    }

    let weightUnit = exerciseSet.weightUnit ?? .pounds
    return Text(
      "\(weightedRepetitions) × \(weight, format: .number.precision(.fractionLength(0...1))) \(weightUnit.displayAbbreviation)"
    )
  }

  private var accessibilityValue: String {
    let setKind = exerciseSet.kind == .warmup ? "Warm-up" : "Working"
    let repetitions = exerciseSet.repetitionMode.description(for: exerciseSet.reps)
    guard let weight = exerciseSet.weight else {
      return "\(setKind), \(repetitions)"
    }

    let weightUnit = exerciseSet.weightUnit ?? .pounds
    let formattedWeight = weight.formatted(
      .number.precision(.fractionLength(0...1))
    )
    return
      "\(setKind), \(repetitions) at \(formattedWeight) \(weightUnit.spokenName)"
  }
}
