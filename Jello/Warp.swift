//
//  Warp.swift
//  Jello
//
//  Created by Dennis Collaris on 22/07/2017.
//  Copyright © 2017 collaris. All rights reserved.
//

import Foundation
import SpriteKit

typealias StepResult = (velocity: CGFloat, force: CGFloat)

class Particle {
  var position: CGPoint
  var force = CGVector(dx: 0, dy: 0)
  var velocity = CGVector(dx: 0, dy: 0)

  var theta: CGFloat = 0
  var immobile: Bool = false
  var mass: CGFloat = 15

  var shape: SKShapeNode
  var scene: SKScene

  init(position: CGPoint, scene: SKScene) {
    self.position = position
    self.scene = scene

    shape = SKShapeNode(circleOfRadius: 6)
    shape.fillColor = SKColor.orange
    shape.strokeColor = SKColor.clear
    shape.position = CGPoint(x: position.x, y: position.y)
    scene.addChild(shape)

    draw()
  }

  func apply(force: CGVector) {
    self.force = self.force.add(vector: force)
  }

  func step() -> StepResult {
    guard !immobile else {
      velocity = CGVector.zero
      force = CGVector.zero

      return (velocity: 0, force: 0)
    }

    force = force.subtract(vector: velocity.scale(by: friction))
    velocity = velocity.add(vector: force.scale(by: CGFloat(1) / mass))
    position = position.add(vector: velocity) // Euler

    let ret = (velocity: abs(velocity.dx) + abs(velocity.dy), force: abs(force.dx) + abs(force.dy))

    force = CGVector.zero

    return ret
  }

  func draw() {
    shape.position = position
    shape.fillColor = immobile ? SKColor.green : SKColor.orange
  }
}

extension Collection where Element == [Particle] {
  func step() -> StepResult {
    var ret: StepResult = (velocity: 0, force: 0)

    for particles in self {
      for particle in particles {
        particle.draw()
        let tuple = particle.step()
        ret.velocity += tuple.velocity
        ret.force += tuple.force
      }
    }

    return ret
  }
}


public func creatPath (for points:[CGPoint]) -> CGMutablePath {
  let path = CGMutablePath()
  path.addLines(between: points)
  path.closeSubpath()
  return path
}

class Spring {
  var a: Particle
  var b: Particle
  var offset: CGVector

  var shape: SKShapeNode
  var scene: SKScene

  init(a: Particle, b: Particle, offset: CGVector, scene: SKScene) {
    self.a = a
    self.b = b
    self.offset = offset
    self.scene = scene

    let path = creatPath(for: [a.position, b.position])
    shape = SKShapeNode()
    shape.path = path
    shape.strokeColor = NSColor.init(white: 1, alpha: 0.5)
    shape.lineWidth = 2
    scene.addChild(shape)

    draw()
  }

  func apply() {
    let pa = a.position
    let pb = b.position

    let da = CGVector(dx: springK * 0.5 * (pb.x - pa.x - offset.dx), dy: springK * 0.5 * (pb.y - pa.y - offset.dy))
    let db = CGVector(dx: springK * 0.5 * (pa.x - pb.x + offset.dx), dy: springK * 0.5 * (pa.y - pb.y + offset.dy))

    a.apply(force: da)
    b.apply(force: db)

    draw()
  }

  func draw() {
    let path = creatPath(for: [a.position, b.position])
    shape.path = path
  }
}

extension Collection where Element == Spring {
  func apply() {
    for spring in self {
      spring.apply()
    }
  }
}


private var GRID_WIDTH = 8
private var GRID_HEIGHT = 8
private var springK: CGFloat = 12
private var friction: CGFloat = 1

extension TimeInterval {
  var milliseconds: Double {
    return self * 1000
  }
}


extension CGPoint {
  func add(vector: CGVector) -> CGPoint {
    return CGPoint(x: self.x + vector.dx, y: self.y + vector.dy)
  }

  func add(point: CGPoint) -> CGPoint {
    return CGPoint(x: self.x + point.x, y: self.y + point.y)
  }

  func subtract(point: CGPoint) -> CGPoint {
    return CGPoint(x: self.x - point.x, y: self.y - point.y)
  }

  func distanceTo(point: CGPoint) -> CGFloat {
    let distx = self.x - point.x
    let disty = self.y - point.y
    return sqrt(pow(distx, 2) + pow(disty, 2))
  }
}

extension CGVector {
  func add(vector: CGVector) -> CGVector {
    return CGVector(dx: self.dx + vector.dx, dy: self.dy + vector.dy)
  }

  func subtract(vector: CGVector) -> CGVector {
    return CGVector(dx: self.dx - vector.dx, dy: self.dy - vector.dy)
  }

  var normalized: CGVector {
    return CGVector(dx: self.dx / CGFloat(GRID_WIDTH-1), dy: self.dy / CGFloat(GRID_HEIGHT-1))
  }

  func scale(by factor: CGFloat) -> CGVector {
    return CGVector(dx: self.dx * factor, dy: self.dy * factor)
  }

  func multiply(size: CGSize) -> CGPoint {
    return CGPoint(x: self.dx * size.width, y: self.dy * size.height)
  }

  func multiply(size: CGSize) -> CGVector {
    return CGVector(dx: self.dx * size.width, dy: self.dy * size.height)
  }
}



@objc class Warp: NSObject {
  var window: NSWindow
  var particles: [[Particle]]
  var springs = [Spring]()
  var steps: Double = 0
  var scene: SKScene
  var draggingParticle: Particle? = nil
  var dragOrigin: CGPoint? = nil

  init(window: NSWindow, scene: SKScene) {
    self.window = window
    self.scene = scene

    particles = (0..<GRID_HEIGHT).map { y in
      return (0..<GRID_WIDTH).map { x in
        let position: CGPoint = CGVector(dx: x, dy: y).normalized.multiply(size: window.frame.size).add(point: window.frame.origin)
        let p = Particle(position: position, scene: scene)
        return p
      }
    }

    for y in 0..<GRID_HEIGHT {
      for x in 0..<GRID_WIDTH {
        if x > 0 {
          springs.append(Spring(
            a: particles[y][x - 1],
            b: particles[y][x],
            offset: CGVector(dx: 1, dy: 0).normalized.multiply(size: window.frame.size),
            scene: scene
          ))
        }

        if y > 0 {
          springs.append(Spring(
            a: particles[y-1][x],
            b: particles[y][x],
            offset: CGVector(dx: 0, dy: 1).normalized.multiply(size: window.frame.size),
            scene: scene
          ))
        }
      }
    }
  }

  @objc func step(delta: TimeInterval) {
    self.steps += delta.milliseconds / 15
    let steps = floor(self.steps)
    self.steps -= steps

    if steps.isZero {
      return
    }

    for _ in 0..<Int(steps) {
      springs.apply()
      _ = particles.step()
    }
  }

  @objc public func startDrag(at point: CGPoint) {
    let closestParticle = particles.reduce((particle: particles[0][0], distance: CGFloat.greatestFiniteMagnitude)) { (result, particles) in
      let closestParticle = particles.reduce((particle: self.particles[0][0], distance: CGFloat.greatestFiniteMagnitude)) { (result, particle) in
        let distance = particle.position.distanceTo(point: point)
        return result.distance < distance ? result : (particle: particle, distance: distance)
      }
      return result.distance < closestParticle.distance ? result : closestParticle
    }

    draggingParticle = closestParticle.particle
    dragOrigin = closestParticle.particle.position.subtract(point: point)

    closestParticle.particle.immobile = true
  }

  @objc public func drag(at point: CGPoint) {
    var point = point.add(point: dragOrigin!)
    draggingParticle?.position = point
  }

  @objc public func endDrag() {
    draggingParticle?.immobile = false
    draggingParticle = nil
    dragOrigin = nil

    let particle = particles[0][0]
    window.setFrameOrigin(NSPoint(x: particle.position.x, y: particle.position.y))
  }

  @objc public func meshPoint(x: Int, y: Int) -> CGPointWarp {
    let position: CGPoint = CGVector(dx: x, dy: y).normalized.multiply(size: window.frame.size)
    let particle = particles[(GRID_HEIGHT - 1) - y][x]

    var windowFrame = window.frame
    windowFrame.origin.y = window.screen!.frame.height - window.frame.origin.y

    return CGPointWarp(
      local: MeshPoint(x: Float(position.x), y: Float(position.y)),
      global: MeshPoint(x: Float(particle.position.x), y: Float(window.screen!.frame.height - particle.position.y))
    )
  }
}
