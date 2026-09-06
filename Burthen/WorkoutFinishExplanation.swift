//
//  WorkoutFinishExplanation.swift
//  Burthen
//

import SwiftUI

struct WorkoutFinishExplanation: View {
  let summary: WorkoutCompletionSummary

  var body: some View {
    VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.small) {
      if summary.completedSetCount == 0 {
        Text("Complete a set to finish this workout.")
      } else {
        Text(
          "Your summary will show ^[\(summary.completedSetCount) completed set](inflect: true) across ^[\(summary.completedExerciseCount) exercise](inflect: true)."
        )

        if summary.unfinishedSetCount > 0 && summary.omittedExerciseCount > 0 {
          Text("Unfinished sets and exercises without completed sets won’t appear in the summary.")
        } else if summary.unfinishedSetCount > 0 {
          Text("Unfinished sets won’t appear in the summary.")
        } else if summary.omittedExerciseCount > 0 {
          Text("Exercises without completed sets won’t appear in the summary.")
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("workout-finish-explanation")
  }
}
