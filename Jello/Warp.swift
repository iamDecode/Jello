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
internal var springK: CGFloat = 8
internal var friction: CGFloat = 0.8
internal let titleBarHeight: CGFloat = 23

// PROBLEM OCCURS WHEN YOU DRAG A WINDOW BEFORE IT EVEN STOPPED ANIMATING!

internal func convert(toPosition i: Int) -> (Int, Int) {
  return (i % GRID_WIDTH, i.unsafeDivided(by: GRID_WIDTH))
}

internal func convert(toIndex x: Int, y: Int) -> Int {
  return (y * GRID_WIDTH) + x
}

@objc class Warp: NSObject {
  var window: NSWindow
  var particles: [Particle]
  var springs = [Spring]()
  var steps: Double = 0
  var scene: SKScene?
  var draggingParticle: Int? = nil
  var dragOrigin: CGPoint? = nil
  var timer: Timer? = nil
  var screenHeight: CGFloat
  var solver: Solver!
  
  @objc init(window: NSWindow) {
    self.window = window
    
    particles = (0 ..< (GRID_WIDTH * GRID_HEIGHT)).map { i in
      let (x, y) = convert(toPosition: i)
      let position: CGPoint = (CGVector(dx: x, dy: y).normalized * window.frame.size) + window.frame.origin
      return Particle(position: position)
    }

    for y in 0..<GRID_HEIGHT {
      for x in 0..<GRID_WIDTH {
        if x > 0 {
          springs.append(Spring(
            a: convert(toIndex: x - 1, y: y),
            b: convert(toIndex: x, y: y),
            offset: CGVector(dx: 1, dy: 0).normalized * window.frame.size
          ))
        }

        if y > 0 {
          springs.append(Spring(
            a: convert(toIndex: x, y: y - 1),
            b: convert(toIndex: x, y: y),
            offset: CGVector(dx: 0, dy: 1).normalized * window.frame.size
          ))
        }
      }
    }

    screenHeight = NSScreen.main!.frame.height
    
    super.init()
    
    self.solver = SemiImplicitEuler(warp: self)

    NotificationCenter.default.addObserver(self, selector: #selector(Warp.didResize), name: NSWindow.didResizeNotification, object: nil)
  }
  
  convenience init(window: NSWindow, scene: SKScene) {
    self.init(window: window)
    self.scene = scene
  }

  @objc func step(delta: TimeInterval) {
    if delta > 0.5 { return }
    self.steps += delta.milliseconds
    let steps = floor(self.steps)
    self.steps -= steps

    if steps.isZero {
      return
    }

    for _ in 0 ..< Int(steps) {
      solver.step(particles: &particles, stepSize: 0.2)
    }

    if let timer = timer, self.force < 20 { // TODO: make configurable maybe
      // TODO: move into timer block itself. not really step logic..
      timer.invalidate()
      self.timer = nil
      draggingParticle = nil
      dragOrigin = nil

      window.setFrameOrigin(NSPoint(x: particles[0].position.x, y: particles[0].position.y))
      window.clearWarp()
    }
  }

  @objc func didResize(notification: NSNotification) {
    guard let window = notification.object as? NSWindow,
          window == self.window else { return }

    for i in (0 ..< (GRID_WIDTH * GRID_HEIGHT)) {
      let (x, y) = convert(toPosition: i)
      let position: CGPoint = (CGVector(dx: x, dy: y).normalized * window.frame.size) + window.frame.origin
      particles[i].position = position
    }

    // TODO: update offsets rather than recompute them.
    springs = []

    for y in 0..<GRID_HEIGHT {
      for x in 0..<GRID_WIDTH {
        if x > 0 {
          springs.append(Spring(
            a: convert(toIndex: x - 1, y: y),
            b: convert(toIndex: x, y: y),
            offset: CGVector(dx: 1, dy: 0).normalized * window.frame.size
          ))
        }

        if y > 0 {
          springs.append(Spring(
            a: convert(toIndex: x, y: y - 1),
            b: convert(toIndex: x, y: y),
            offset: CGVector(dx: 0, dy: 1).normalized * window.frame.size
          ))
        }
      }
    }
  }

  @objc public func startDrag(at point: CGPoint) {
    let closest = particles
      .map { $0.position.distanceTo(point: point) }
      .enumerated()
      .min( by: { $0.1 < $1.1 } )!
  
    draggingParticle = closest.offset
    dragOrigin = particles[closest.offset].position - point
    particles[closest.offset].immobile = true
    self.window.ignoresMouseEvents = true
  }

  @objc public func drag(at point: CGPoint) {
    if let dragOrigin = dragOrigin {
      let point = point + dragOrigin
      if let i = draggingParticle {
        particles[i].position = point
      }
    } else {
      // Very dirty workaround
      startDrag(at: NSEvent.mouseLocation)
      drag(at: point)
    }
  }

  @objc public func endDrag() {
    self.window.ignoresMouseEvents = false
    draggingParticle = nil
    for i in 0 ..< particles.count {
      particles[i].immobile = false
    }

    if timer != nil { // Dont start a after-drag loop when there is already one running
      return
    }
    
    timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { (timer) in
      if self.draggingParticle != nil { return } // when dragging during the after-drag loop, disable the loop

      self.window.drawWarp()

//      for _ in 0..<10 {
//        self.step(delta: 0.001)
//      }
      self.step(delta: 1/60)
    }
  }

  @objc public func meshPoint(x: Int, y: Int) -> CGPointWarp {
    let position: CGPoint = CGVector(dx: x, dy: y).normalized * window.frame.size
    let particle = particles[convert(toIndex: x, y: (GRID_HEIGHT - 1) - y)]

    var windowFrame = window.frame
    windowFrame.origin.y = window.screen!.frame.height - window.frame.origin.y // This does not seem to do anything..?

    return CGPointWarp(
      local: MeshPoint(x: Float(position.x), y: Float(position.y)),
      global: MeshPoint(x: Float(round(particle.position.x)), y: Float(screenHeight - round(particle.position.y))) // TODO: use UIScreen.convert
    )
  }

  @objc var velocity: CGFloat {
    return solver.velocity
  }

  @objc var force: CGFloat {
    return solver.force
  }
}
