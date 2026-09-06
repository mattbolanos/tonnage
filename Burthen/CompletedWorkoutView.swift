//
//  CompletedWorkoutView.swift
//  Burthen
//

import SwiftUI

struct CompletedWorkoutView: View {
  let workout: Workout
  var showsCompletion = false

  @State private var templateSeed: WorkoutTemplateSeed?

  var body: some View {
    let orderedExercises = workout.orderedExercises.filter { workoutExercise in
      workoutExercise.exerciseSets.contains { $0.isCompleted }
    }

    List {
      CompletedWorkoutHeader(workout: workout, showsCompletion: showsCompletion)

      if showsCompletion {
        Button(
          "Save as Template",
          systemImage: "rectangle.stack.badge.plus",
          action: presentTemplateEditor
        )
        .disabled(workout.templateExercisePlans.isEmpty)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityHint("Creates a reusable template from this workout’s exercises.")
      }

      if orderedExercises.isEmpty {
        ContentUnavailableView {
          ContentUnavailableLogoLabel(title: "No Exercises")
        } description: {
          Text("No exercises were recorded for this workout.")
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      } else {
        ForEach(orderedExercises) { workoutExercise in
          CompletedWorkoutExerciseCard(workoutExercise: workoutExercise)
            .listRowInsets(LayoutMetrics.Insets.cardRow)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle("Workout Summary")
    .navigationBarTitleDisplayMode(.large)
    .sheet(item: $templateSeed) { seed in
      AddWorkoutTemplateView(seed: seed)
    }
  }

  private func presentTemplateEditor() {
    templateSeed = WorkoutTemplateSeed(workout: workout)
  }
}
