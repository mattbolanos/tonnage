//
//  CircularProgress.swift
//  Burthen
//

import SwiftUI

struct CircularProgress: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let value: Double

  @ScaledMetric(relativeTo: .body)
  private var diameter = LayoutMetrics.Size.circularProgress

  @ScaledMetric(relativeTo: .body)
  private var lineWidth = LayoutMetrics.StrokeWidth.circularProgress

  private var progress: CGFloat {
    CGFloat(min(max(value, 0), 1))
  }

  var body: some View {
    ZStack {
      Circle()
        .stroke(.tint, lineWidth: lineWidth)
        .opacity(0.25)

      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          .tint,
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(reduceMotion ? nil : .smooth, value: progress)
    }
    .frame(width: diameter, height: diameter)
  }
}
