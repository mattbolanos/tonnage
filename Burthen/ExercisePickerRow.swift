//
//  ExercisePickerRow.swift
//  Burthen
//

import SwiftUI

struct ExercisePickerRow: View {
  let exercise: Exercise
  let isAlreadyAdded: Bool
  let isSelected: Bool
  var isInWorkout = false
  let action: () -> Void

  private var accessibilityValue: String {
    if isAlreadyAdded {
      "Already added"
    } else if isInWorkout {
      isSelected ? "In workout, selected to add again" : "In workout, not selected"
    } else if isSelected {
      "Selected"
    } else {
      "Not selected"
    }
  }

  var body: some View {
    Button(action: action) {
      HStack {
        Text(exercise.name)
          .foregroundStyle(.primary)

        Spacer()

        Image(systemName: isAlreadyAdded || isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isSelected && !isAlreadyAdded ? Color.pink : Color.secondary)
          .accessibilityHidden(true)
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(isAlreadyAdded)
    .accessibilityIdentifier("exercise-option-\(exercise.id)")
    .accessibilityLabel(exercise.name)
    .accessibilityValue(accessibilityValue)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
