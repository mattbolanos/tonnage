import SwiftUI

/// Native form controls avoid competing wheel and sheet scroll gestures at large text sizes.
struct ExerciseSetAccessibilityForm: View {
  @Binding var kind: ExerciseSetKind
  @Binding var repetitions: Int
  @Binding var wholeWeight: Int
  @Binding var usesHalfWeight: Bool
  let weightUnit: WeightUnit
  let confirmation: String?

  var body: some View {
    Form {
      Section {
        Picker("Set Type", selection: $kind) {
          Text("Working").tag(ExerciseSetKind.working)
          Text("Warm-up").tag(ExerciseSetKind.warmup)
        }
      }

      Section("Repetitions") {
        Stepper(value: $repetitions, in: ExerciseSetPickerControls.repetitionRange) {
          Text("\(repetitions) reps")
        }
        .accessibilityLabel("Repetitions")
        .accessibilityValue("\(repetitions) repetitions")
        .accessibilityIdentifier("set-repetitions")
      }

      Section("Weight") {
        Stepper(value: $wholeWeight, in: ExerciseSetPickerControls.wholeWeightRange) {
          Text("\(weight, format: .number.precision(.fractionLength(0...1))) \(weightUnit.displayAbbreviation)")
        }
        .accessibilityLabel("Weight")
        .accessibilityValue("\(weight.formatted()) \(weightUnit.spokenName)")
        .accessibilityIdentifier("set-weight")

        Toggle("Half \(weightUnit.spokenName)", isOn: $usesHalfWeight)
          .disabled(wholeWeight == ExerciseSetPickerControls.wholeWeightRange.upperBound)
      }

      if let confirmation {
        Section {
          Label(confirmation, systemImage: "checkmark.circle")
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var weight: Decimal {
    Decimal(wholeWeight * 2 + (usesHalfWeight ? 1 : 0)) / 2
  }
}
