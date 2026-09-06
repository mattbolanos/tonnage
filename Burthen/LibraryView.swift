//
//  LibraryView.swift
//  Burthen
//

import SwiftData
import SwiftUI

struct LibraryView: View {
  var body: some View {
    NavigationStack {
      Form {
        Section {
          NavigationLink {
            ExerciseManagementView()
          } label: {
            Text("Exercises")
          }

          NavigationLink {
            TemplateManagementView()
          } label: {
            Text("Workout Templates")
          }
        }
      }
      .navigationTitle("Library")
    }
  }
}

#Preview {
  LibraryView()
    .modelContainer(for: BurthenSchema.models, inMemory: true)
}
