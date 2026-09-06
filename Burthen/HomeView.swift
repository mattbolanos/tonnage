//
//  HomeView.swift
//  Burthen
//

import SwiftData
import SwiftUI

struct HomeView: View {
  @Query private var templates: [WorkoutTemplate]

  @Binding var navigationPath: [HomeRoute]

  let workouts: [Workout]
  let resumeActiveWorkout: () -> Void

  @State private var isCreatingTemplate = false

  private var activeWorkout: Workout? {
    workouts.first { $0.status == .inProgress }
  }

  private var completedWorkouts: [Workout] {
    workouts
      .filter { $0.status == .completed }
      .sorted(by: isMoreRecentlyCompleted)
  }

  private var hasActiveTemplates: Bool {
    templates.contains { !$0.isArchived }
  }

  var body: some View {
    let activeWorkout = activeWorkout
    let completedWorkouts = completedWorkouts

    NavigationStack(path: $navigationPath) {
      List {
        if let activeWorkout {
          Section {
            Button(action: resumeActiveWorkout) {
              ActiveWorkoutRow(workout: activeWorkout)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Returns to the active workout.")
          } header: {
            SectionHeader("Active")
          }
        }

        if !completedWorkouts.isEmpty {
          Section {
            ForEach(completedWorkouts) { workout in
              Button {
                showCompletedWorkout(workout)
              } label: {
                CompletedWorkoutRow(workout: workout)
              }
              .buttonStyle(.plain)
              .accessibilityHint("Shows the exercises and sets from this workout.")
            }
          } header: {
            SectionHeader("Recent")
          }
        }
      }
      .overlay {
        if activeWorkout == nil, completedWorkouts.isEmpty {
          ContentUnavailableView {
            ContentUnavailableLogoLabel(title: "No Workouts Yet")
          } description: {
            Text("Start a blank workout or choose a template to begin.")
          }
        }
      }
      .navigationTitle("Workouts")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu("Add Workout", systemImage: "plus") {
            NavigationLink(value: HomeRoute.blank) {
              Label("Blank Workout", systemImage: "doc")
            }
            if !hasActiveTemplates {
              Button(
                "Create a Template",
                systemImage: "rectangle.stack.badge.plus",
                action: createTemplate
              )
            } else {
              NavigationLink(value: HomeRoute.templates) {
                Label("Choose a Template", systemImage: "rectangle.stack")
              }
            }
          }
          .disabled(activeWorkout != nil)
          .accessibilityHint(
            activeWorkout == nil
              ? "Choose how to start a workout."
              : "Finish or discard the active workout before starting a new one."
          )
        }
      }
      .navigationDestination(for: HomeRoute.self) { route in
        switch route {
        case .blank:
          BlankWorkoutView()
        case .templates:
          WorkoutTemplatePickerView()
        case .completedWorkout(let workoutID), .finishedWorkout(let workoutID):
          if let workout = workouts.first(where: { $0.id == workoutID }) {
            CompletedWorkoutView(
              workout: workout,
              showsCompletion: route == .finishedWorkout(workoutID)
            )
          } else {
            ContentUnavailableView {
              ContentUnavailableLogoLabel(title: "Workout Unavailable")
            } description: {
              Text("This workout is no longer available.")
            }
          }
        }
      }
      .sheet(isPresented: $isCreatingTemplate) {
        AddWorkoutTemplateView(offersWorkoutStart: true)
      }
    }
  }

  private func createTemplate() {
    isCreatingTemplate = true
  }

  private func showCompletedWorkout(_ workout: Workout) {
    navigationPath.append(.completedWorkout(workout.id))
  }

  private func isMoreRecentlyCompleted(_ lhs: Workout, _ rhs: Workout) -> Bool {
    let lhsDate = lhs.endedAt ?? lhs.updatedAt
    let rhsDate = rhs.endedAt ?? rhs.updatedAt

    if lhsDate == rhsDate {
      return lhs.id.uuidString > rhs.id.uuidString
    }
    return lhsDate > rhsDate
  }
}

private struct ActiveWorkoutRow: View {
  let workout: Workout

  var body: some View {
    HStack(spacing: LayoutMetrics.Spacing.large) {
      VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.extraSmall) {
        Text(workout.displayName)
          .font(.headline)
          .foregroundStyle(.primary)

        Text(
          workout.startedAt,
          format: .dateTime
            .weekday(.abbreviated)
            .month(.abbreviated)
            .day()
            .hour()
            .minute()
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
      }

      Spacer(minLength: LayoutMetrics.Spacing.small)

      Image(systemName: "play.fill")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.green)
        .frame(
          width: LayoutMetrics.Size.resumeWorkoutButton,
          height: LayoutMetrics.Size.resumeWorkoutButton
        )
        .background {
          Circle()
            .fill(Color.green.opacity(0.18))
        }
        .accessibilityLabel("Resume")
    }
    .frame(minHeight: LayoutMetrics.Size.workoutRowContentHeight)
    .padding(.vertical, LayoutMetrics.Spacing.extraSmall)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}

private struct CompletedWorkoutRow: View {
  let workout: Workout

  var body: some View {
    HStack(alignment: .top, spacing: LayoutMetrics.Spacing.medium) {
      VStack(alignment: .leading, spacing: LayoutMetrics.Spacing.extraSmall) {
        Text(workout.displayName)
          .font(.headline)
          .foregroundStyle(.primary)

        Text(
          workout.endedAt ?? workout.updatedAt,
          format: .dateTime
            .weekday(.abbreviated)
            .month(.abbreviated)
            .day()
            .hour()
            .minute()
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
      }

      Spacer(minLength: LayoutMetrics.Spacing.small)

      TrainingLoadText(load: workout.volumeLoad)
        .font(.headline)
    }
    .frame(
      maxWidth: .infinity,
      minHeight: LayoutMetrics.Size.workoutRowContentHeight,
      alignment: .leading
    )
    .padding(.vertical, LayoutMetrics.Spacing.extraSmall)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  @Previewable @State var navigationPath: [HomeRoute] = []

  HomeView(
    navigationPath: $navigationPath,
    workouts: [],
    resumeActiveWorkout: {}
  )
  .modelContainer(for: BurthenSchema.models, inMemory: true)
}
