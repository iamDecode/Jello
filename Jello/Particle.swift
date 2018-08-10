//
//  Particle.swift
//  JelloInject
//
//  Created by Dennis Collaris on 05/08/2018.
//  Copyright © 2018 collaris. All rights reserved.
//

typealias StepResult = (velocity: CGFloat, force: CGFloat)

class Particle {
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

  func apply(force: CGVector) {
    self.force += force
  }

  func step(height: CGFloat) -> StepResult {
    guard !immobile else {
      velocity = CGVector.zero
      force = CGVector.zero

      return (velocity: 0, force: 0)
    }

    force -= velocity * friction
    velocity += force / mass
    position += velocity // Euler

    if position.y > height - titleBarHeight {
      position.y = height - titleBarHeight
      force.dy *= -1
      velocity.dy *= -1
    }/* else if position.y < 0 {
      position.y = 0
      force.dy *= -1
      velocity.dy *= -1
    }*/

    let ret = (velocity: abs(velocity.dx) + abs(velocity.dy), force: abs(force.dx) + abs(force.dy))

    force = CGVector.zero

    return ret
  }
}

extension Collection where Iterator.Element == [Particle] {
  func step(height: CGFloat) -> StepResult {
    var ret: StepResult = (velocity: 0, force: 0)

    for particles in self {
      for particle in particles {
        let tuple = particle.step(height: height)
        ret.velocity += tuple.velocity
        ret.force += tuple.force
      }
    }

    return ret
  }
}


class SKParticle: Particle {
  var shape: SKShapeNode
  var scene: SKScene

  init(position: CGPoint, scene: SKScene) {
    self.scene = scene

    shape = SKShapeNode(circleOfRadius: 6)
    shape.fillColor = SKColor.orange
    shape.strokeColor = SKColor.clear
    shape.position = CGPoint(x: position.x, y: position.y)
    scene.addChild(shape)

    super.init(position: position)

    draw()
  }

  func draw() {
    shape.position = position
    shape.fillColor = immobile ? SKColor.green : SKColor.orange
  }
}

extension Collection where Element == [SKParticle] {
  func step(height: CGFloat) -> StepResult {
    var ret: StepResult = (velocity: 0, force: 0)

    for particles in self {
      for particle in particles {
        particle.draw()
        let tuple = particle.step(height: height)
        ret.velocity += tuple.velocity
        ret.force += tuple.force
      }
    }

    return ret
  }
}
