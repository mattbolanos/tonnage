//
//  LayoutMetrics.swift
//  Burthen
//

import SwiftUI

/// Shared layout values for deliberate overrides of SwiftUI's native spacing.
///
/// Prefer the defaults supplied by containers such as `Form`, `List`, and
/// `Section`. Use these metrics when a custom composition needs an explicit
/// relationship between elements.
enum LayoutMetrics {
  enum Spacing {
    static let extraSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 24
    static let doubleExtraLarge: CGFloat = 32
  }

  enum Padding {
    static let card = Spacing.large
    static let horizontalContent = Spacing.large
  }

  enum CornerRadius {
    static let card: CGFloat = 22
  }

  enum Size {
    static let contentUnavailableLogoWidth: CGFloat = 64
    static let circularProgress: CGFloat = 24
    static let setNumberColumn = Spacing.large
    static let workoutRowContentHeight: CGFloat = 44
    static let resumeWorkoutButton = workoutRowContentHeight
    static let setCompletionControl = workoutRowContentHeight
    /// Trims the wheel picker's near-invisible fade rows so the controls
    /// beneath it sit close to the value they modify.
    static let wheelPicker: CGFloat = 176
  }

  enum StrokeWidth {
    static let circularProgress: CGFloat = 6
  }

  enum Insets {
    static let cardRow = EdgeInsets(
      top: Spacing.small,
      leading: Spacing.large,
      bottom: Spacing.small,
      trailing: Spacing.large
    )

    static let finalActionRow = EdgeInsets(
      top: Spacing.large,
      leading: Spacing.large,
      bottom: Spacing.extraLarge,
      trailing: Spacing.large
    )
  }
}
