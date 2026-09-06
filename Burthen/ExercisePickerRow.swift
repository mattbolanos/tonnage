//
//  ExercisePickerRow.swift
//  Burthen
//

import SwiftUI

struct ExercisePickerRow: View {
  let exercise: Exercise
  let isAlreadyAdded: Bool
  let isSelected: Bool
  let action: () -> Void

  private var trackingSummary: String {
    let load = switch exercise.loadMode {
    case .externalResistance: "External resistance"
    case .bodyweight: "Bodyweight"
    }
    let repetitions = exercise.repetitionMode == .perSide ? "Per side" : "Standard reps"
    return "\(load) · \(repetitions)"
  }

  private var accessibilityValue: String {
    if isAlreadyAdded {
      "Already added"
    } else if isSelected {
      "Selected"
    } else {
      "Not selected"
    }
  }

  var body: some View {
    Button(action: action) {
      HStack {
        VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.extraSmall) {
          Text(exercise.name)
            .foregroundStyle(.primary)
          Text(trackingSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Image(systemName: isAlreadyAdded || isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isSelected && !isAlreadyAdded ? Color.pink : Color.secondary)
          .accessibilityHidden(true)
      }
      .frame(minHeight: LayoutMetrics.Size.workoutRowContentHeight)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(isAlreadyAdded)
    .accessibilityIdentifier("exercise-option-\(exercise.id)")
    .accessibilityLabel(exercise.name)
    .accessibilityValue(accessibilityValue)
    .accessibilityHint(trackingSummary)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
