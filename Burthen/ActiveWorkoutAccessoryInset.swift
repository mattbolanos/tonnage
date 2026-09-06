//
//  ActiveWorkoutAccessoryInset.swift
//  Burthen
//

import SwiftUI

/// Keeps the tab and its navigation state stable while the accessory appears
/// and disappears. An empty inset contributes no accessory host or background.
struct ActiveWorkoutAccessoryInset: ViewModifier {
  let workout: Workout?
  let resume: () -> Void

  func body(content: Content) -> some View {
    content.safeAreaInset(edge: .bottom) {
      if let workout {
        ActiveWorkoutAccessory(workout: workout, resume: resume)
          .padding(.vertical, LayoutMetrics.Spacing.small)
          .glassEffect(.regular)
          .padding(.horizontal, LayoutMetrics.Padding.horizontalContent)
          .padding(.bottom, LayoutMetrics.Spacing.small)
      }
    }
  }
}
