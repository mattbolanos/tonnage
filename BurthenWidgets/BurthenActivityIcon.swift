import ActivityKit
import SwiftUI
import WidgetKit

struct BurthenActivityIcon: View {
  @ScaledMetric(relativeTo: .subheadline)
  private var iconWidth = LayoutMetrics.Size.liveActivityLogoWidth

  var body: some View {
    Image("BurthenActivityIcon")
      .resizable()
      .scaledToFit()
      .frame(width: iconWidth)
      .accessibilityLabel("Burthen")
  }
}
