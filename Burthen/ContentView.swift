//
//  ContentView.swift
//  Burthen
//
//  Created by Matt Bolaños on 7/25/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
  @Query(sort: \Workout.startedAt, order: .reverse)
  private var workouts: [Workout]

  @State private var selection = AppTab.home
  @State private var homeNavigationPath: [HomeRoute] = []
  @State private var activeWorkoutNavigationPath: [ActiveWorkoutExerciseRoute] = []
  @State private var presentedWorkout: Workout?
  @State private var lastCompletedWorkoutID: UUID?

  private var activeWorkout: Workout? {
    workouts.first { $0.status == .inProgress }
  }

  private var workoutActivityDescriptor: WorkoutActivityDescriptor? {
    activeWorkout.map {
      WorkoutActivityDescriptor(
        id: $0.id,
        name: $0.displayName,
        startedAt: $0.startedAt
      )
    }
  }

  var body: some View {
    TabView(selection: $selection) {
      Tab("Home", systemImage: "house", value: AppTab.home) {
        HomeView(
          navigationPath: $homeNavigationPath,
          workouts: workouts,
          resumeActiveWorkout: showActiveWorkout
        )
        .tint(nil)
        .modifier(
          ActiveWorkoutAccessoryInset(
            workout: activeWorkout,
            resume: showActiveWorkout
          )
        )
      }

      Tab("Library", systemImage: "books.vertical", value: AppTab.library) {
        LibraryView()
          .tint(nil)
          .modifier(
            ActiveWorkoutAccessoryInset(
              workout: activeWorkout,
              resume: showActiveWorkout
            )
          )
      }
    }
    .tint(.pink)
    .sheet(item: $presentedWorkout) { workout in
      ActiveWorkoutView(
        workout: workout,
        navigationPath: $activeWorkoutNavigationPath,
        onComplete: showFinishedWorkout,
        onDiscard: showHome,
        onMinimize: minimizeWorkout
      )
      .tint(nil)
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    }
    .sensoryFeedback(.success, trigger: lastCompletedWorkoutID)
    .onChange(
      of: activeWorkout?.id,
      initial: true,
      activeWorkoutDidChange
    )
    .task(id: activeWorkout?.id) {
      await WorkoutActivityManager.synchronize(
        with: workoutActivityDescriptor
      )
    }
  }

  private func activeWorkoutDidChange(_: UUID?, _ newID: UUID?) {
    if newID != nil {
      activeWorkoutNavigationPath.removeAll()
      homeNavigationPath.removeAll()
      showActiveWorkout()
    } else {
      minimizeWorkout()
    }
  }

  private func showFinishedWorkout(_ workout: Workout) {
    minimizeWorkout()
    selection = .home
    homeNavigationPath = [.finishedWorkout(workout.id)]
    lastCompletedWorkoutID = workout.id
  }

  private func showActiveWorkout() {
    presentedWorkout = activeWorkout
  }

  private func minimizeWorkout() {
    presentedWorkout = nil
  }

  private func showHome() {
    minimizeWorkout()
    homeNavigationPath.removeAll()
    selection = .home
  }
}

#Preview {
  ContentView()
    .modelContainer(for: BurthenSchema.models, inMemory: true)
}
