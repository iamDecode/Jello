//
//  Warp.swift
//  Jello
//
//  Created by Dennis Collaris on 22/07/2017.
//  Copyright © 2017 collaris. All rights reserved.
//

import Foundation
import SpriteKit


public func createPath (for points:[CGPoint]) -> CGMutablePath {
  let path = CGMutablePath()
  path.addLines(between: points)
  path.closeSubpath()
  return path
}

internal var GRID_WIDTH = 8
internal var GRID_HEIGHT = 8
internal var springK: CGFloat = 5
internal var friction: CGFloat = 0.8
internal let titleBarHeight: CGFloat = 23


@objc class Warp: NSObject {
  var window: NSWindow
  var particles: [[SKParticle]]
  var springs = [SKSpring]()
  var steps: Double = 0
  var scene: SKScene
  var draggingParticle: SKParticle? = nil
  var dragOrigin: CGPoint? = nil
  var timer: Timer? = nil
  var screenHeight: CGFloat
  var lastResult: StepResult?

  init(window: NSWindow, scene: SKScene) {
    self.window = window
    self.scene = scene

    particles = (0..<GRID_HEIGHT).map { y in
      return (0..<GRID_WIDTH).map { x in
        let position: CGPoint = CGVector(dx: x, dy: y).normalized.multiply(size: window.frame.size).add(point: window.frame.origin)
        return SKParticle(position: position, scene: scene)
      }
    }

    for y in 0..<GRID_HEIGHT {
      for x in 0..<GRID_WIDTH {
        if x > 0 {
          springs.append(SKSpring(
            a: particles[y][x - 1],
            b: particles[y][x],
            offset: CGVector(dx: 1, dy: 0).normalized.multiply(size: window.frame.size),
            scene: scene
          ))
        }

        if y > 0 {
          springs.append(SKSpring(
            a: particles[y-1][x],
            b: particles[y][x],
            offset: CGVector(dx: 0, dy: 1).normalized.multiply(size: window.frame.size),
            scene: scene
          ))
        }
      }
    }

    screenHeight = NSScreen.main!.frame.height
    
    super.init()

    NotificationCenter.default.addObserver(self, selector: #selector(Warp.didResize), name: NSWindow.didResizeNotification, object: nil)
  }

  @objc func step(delta: TimeInterval) {
    if delta > 0.5 { return }
    self.steps += delta.milliseconds / 4
    let steps = floor(self.steps)
    self.steps -= steps

    if steps.isZero {
      return
    }

    for _ in 0..<Int(steps) {
      springs.apply()
      lastResult = particles.step(height: screenHeight)
    }

    if let timer = timer, let lastResult = lastResult, lastResult.force < 20 { // TODO: make configurable maybe
      timer.invalidate()
      self.timer = nil
      draggingParticle = nil
      dragOrigin = nil

      let particle = particles[0][0]
      window.setFrameOrigin(NSPoint(x: particle.position.x, y: particle.position.y))

      window.clearWarp()
    }
  }

  @objc func didResize(notification: NSNotification) {
    guard let window = notification.object as? NSWindow,
          window == self.window else { return }

    for y in 0..<GRID_HEIGHT {
      for x in 0..<GRID_WIDTH {
        let position: CGPoint = CGVector(dx: x, dy: y).normalized.multiply(size: window.frame.size).add(point: window.frame.origin)
        particles[y][x].position = position
        particles[y][x].draw()
      }
    }

    // TODO: update offsets rather than recompute them.
    springs = []

    for y in 0..<GRID_HEIGHT {
      for x in 0..<GRID_WIDTH {
        if x > 0 {
          springs.append(SKSpring(
            a: particles[y][x - 1],
            b: particles[y][x],
            offset: CGVector(dx: 1, dy: 0).normalized.multiply(size: window.frame.size),
            scene: scene
          ))
        }

        if y > 0 {
          springs.append(SKSpring(
            a: particles[y-1][x],
            b: particles[y][x],
            offset: CGVector(dx: 0, dy: 1).normalized.multiply(size: window.frame.size),
            scene: scene
          ))
        }
      }
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
    if let dragOrigin = dragOrigin {
      let point = point.add(point: dragOrigin)
      draggingParticle?.position = point
    }
  }

  @objc public func endDrag() {
    draggingParticle?.immobile = false

    timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { (timer) in
      self.window.drawWarp()
      self.step(delta: 0.01)
    }
  }

  @objc public func meshPoint(x: Int, y: Int) -> CGPointWarp {
    let position: CGPoint = CGVector(dx: x, dy: y).normalized.multiply(size: window.frame.size)
    let particle = particles[(GRID_HEIGHT - 1) - y][x]

    var windowFrame = window.frame
    windowFrame.origin.y = window.screen!.frame.height - window.frame.origin.y

    return CGPointWarp(
      local: MeshPoint(x: Float(position.x), y: Float(position.y)),
      global: MeshPoint(x: Float(round(particle.position.x)), y: Float(screenHeight - round(particle.position.y)))
    )
  }

  @objc var velocity: CGFloat {
    return lastResult?.velocity ?? 0
  }

  @objc var force: CGFloat {
    return lastResult?.force ?? 0
  }
}
