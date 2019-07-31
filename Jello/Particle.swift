//
//  Particle.swift
//  JelloInject
//
//  Created by Dennis Collaris on 05/08/2018.
//  Copyright © 2018 collaris. All rights reserved.
//

import Foundation

typealias StepResult = (velocity: CGFloat, force: CGFloat)

struct Particle {
  var position: CGPoint
  var force = CGVector(dx: 0, dy: 0)
  var velocity = CGVector(dx: 0, dy: 0)
  var acceleration: CGVector {
    get { return force / mass }
  }

  var immobile = false
  var mass: CGFloat = 15

  init(position: CGPoint) {
    self.position = position
  }

  mutating func apply(force: CGVector) {
    self.force += force
  }
}
