//
//  ExerciseSetPickerControls.swift
//  Burthen
//

import SwiftUI

struct ExerciseSetPickerControls: View {
  static let repetitionRange = 1...49
  static let wholeWeightRange = 0...399

  @ScaledMetric(relativeTo: .title2)
  private var unitSpacing = LayoutMetrics.Spacing.small
  @ScaledMetric(relativeTo: .title2)
  private var wheelHeight = LayoutMetrics.Size.wheelPicker

  @Binding var kind: ExerciseSetKind
  @Binding var repetitions: Int
  @Binding var wholeWeight: Int
  @Binding var usesHalfWeight: Bool
  let weightUnit: WeightUnit

  var body: some View {
    VStack(spacing: LayoutMetrics.Spacing.medium) {
      Picker("Set Type", selection: $kind) {
        Text("Working")
          .tag(ExerciseSetKind.working)
        Text("Warm-up")
          .tag(ExerciseSetKind.warmup)
      }
      .pickerStyle(.segmented)

      HStack(alignment: .top, spacing: LayoutMetrics.Spacing.large) {
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

        VStack(spacing: LayoutMetrics.Spacing.medium) {
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
                    // Keep the fraction width stable while the wheel moves.
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

          Toggle(isOn: $usesHalfWeight) {
            Text("\(usesHalfWeight ? "−" : "+") ½ \(weightUnit.displayAbbreviation)")
          }
          .toggleStyle(.button)
          .buttonStyle(.bordered)
          .controlSize(.large)
          .accessibilityLabel("Half \(weightUnit.spokenName)")
          .disabled(wholeWeight == Self.wholeWeightRange.upperBound)
        }
        .frame(maxWidth: .infinity)
      }
    }
  }

  private var weightAccessibilityValue: String {
    let halfSteps = wholeWeight * 2 + (usesHalfWeight ? 1 : 0)
    let weight = Decimal(halfSteps) / 2
    return "\(weight) \(weightUnit.spokenName)"
  }
}
