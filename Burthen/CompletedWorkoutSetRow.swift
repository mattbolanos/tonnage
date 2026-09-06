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

  private var setSummary: Text {
    guard let weight = exerciseSet.weight else {
      return Text("\(exerciseSet.reps) reps")
    }

    let weightUnit = exerciseSet.weightUnit ?? .pounds
    return Text(
      "\(exerciseSet.reps) × \(weight, format: .number.precision(.fractionLength(0...1))) \(weightUnit.displayAbbreviation)"
    )
  }

  private var accessibilityValue: String {
    let setKind = exerciseSet.kind == .warmup ? "Warm-up" : "Working"
    let repetitions = "\(exerciseSet.reps) repetitions"
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
