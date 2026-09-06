//
//  HomeRoute.swift
//  Burthen
//

import Foundation

enum HomeRoute: Hashable {
  case blank
  case templates
  case completedWorkout(UUID)
  case finishedWorkout(UUID)
}
