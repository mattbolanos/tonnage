//
//  WorkoutTemplatePickerView.swift
//  Burthen
//

import SwiftData
import SwiftUI

struct WorkoutTemplatePickerView: View {
  @Environment(\.modelContext) private var modelContext

  @Query(
    filter: #Predicate<WorkoutTemplate> { !$0.isArchived },
    sort: \WorkoutTemplate.name
  )
  private var activeTemplates: [WorkoutTemplate]

  @State private var isShowingError = false
  @State private var errorMessage = ""

  var body: some View {
    List(activeTemplates) { template in
      Button {
        startWorkout(from: template)
      } label: {
        TemplateRowView(template: template)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .disabled(!template.isReadyToStart)
      .accessibilityHint(
        template.isReadyToStart
          ? "Starts a new workout from this template."
          : "Edit this template in Library before using it."
      )
    }
    .overlay {
      if activeTemplates.isEmpty {
        ContentUnavailableView(
          "No Templates Yet",
          systemImage: "rectangle.stack",
          description: Text("Create a workout template in Library to use it here.")
        )
      }
    }
    .navigationTitle("Choose a Template")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Workout Couldn’t Be Started", isPresented: $isShowingError) {
      Button("OK", role: .cancel) { }
    } message: {
      Text(errorMessage)
    }
  }

  private func startWorkout(from template: WorkoutTemplate) {
    do {
      _ = try TrainingDataStore(modelContext: modelContext).startWorkout(
        from: template
      )
      try modelContext.save()
    } catch {
      errorMessage = templateErrorMessage(for: error)
      isShowingError = true
    }
  }
}

#Preview {
  NavigationStack {
    WorkoutTemplatePickerView()
  }
  .modelContainer(for: BurthenSchema.models, inMemory: true)
}
