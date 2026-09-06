//
//  BurthenApp.swift
//  Burthen
//
//  Created by Matt Bolaños on 7/25/26.
//

import SwiftData
import SwiftUI

@main
struct BurthenApp: App {
  private let modelContainer: ModelContainer = {
    #if DEBUG
    let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
    #else
    let isUITesting = false
    #endif

    let configuration = ModelConfiguration(
      schema: BurthenSchema.schema,
      isStoredInMemoryOnly: isUITesting
    )

    do {
      return try ModelContainer(
        for: BurthenSchema.schema,
        configurations: [configuration]
      )
    } catch {
      fatalError("Unable to create the Burthen model container: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .preferredColorScheme(.dark)
    }
    .modelContainer(modelContainer)
  }
}
