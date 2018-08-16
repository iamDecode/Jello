//
//  Warp.swift
//  Jello
//
//  Created by Dennis Collaris on 22/07/2017.
//  Copyright © 2017 collaris. All rights reserved.
//

import Foundation
import SpriteKit


internal var GRID_WIDTH = 8
internal var GRID_HEIGHT = 8
internal var springK: CGFloat = 7
internal var friction: CGFloat = 1
internal let titleBarHeight: CGFloat = 23


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
            offset: CGVector(dx: 1, dy: 0).normalized * window.frame.size,
            springK: springK
          ))
        }

        if y > 0 {
          springs.append(Spring(
            a: convert(toIndex: x, y: y - 1),
            b: convert(toIndex: x, y: y),
            offset: CGVector(dx: 0, dy: 1).normalized * window.frame.size,
            springK: springK
          ))
        }
      }
    }

    screenHeight = NSScreen.screens.first!.frame.height
    
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
    self.steps += delta.milliseconds / 3
    let steps = floor(self.steps)
    self.steps -= steps

    if steps.isZero {
      return
    }

    for _ in 0 ..< Int(steps) {
      solver.step(particles: &particles, stepSize: 0.5)
    }

    if let timer = timer, self.force < 20 { // TODO: make configurable maybe
      // TODO: move into timer block itself. not really step logic..
      timer.invalidate()
      self.timer = nil
      
      let frame = NSRect(
        x: particles[0].position.x,
        y: particles[0].position.y,
        width: window.frame.width,
        height: window.frame.height
      )
      
      CATransaction.begin()
      CATransaction.setCompletionBlock {
        self.window.clearWarp()
      }
      self.window.clearWarp()
      window.setFrame(frame, display: false)
      CATransaction.commit()
      
//      self.window.clearWarp()
//      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//        //self.window.setFrame(frame, display: false)
//        self.window.setFrameOrigin(frame.origin)
//      }
      
      self.window.styleMask.insert(NSWindow.StyleMask.resizable)
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
            offset: CGVector(dx: 1, dy: 0).normalized * window.frame.size,
            springK: springK
          ))
        }

        if y > 0 {
          springs.append(Spring(
            a: convert(toIndex: x, y: y - 1),
            b: convert(toIndex: x, y: y),
            offset: CGVector(dx: 0, dy: 1).normalized * window.frame.size,
            springK: springK
          ))
        }
      }
    }
  }

  @objc public func startDrag(at point: CGPoint) {
    let distances = particles.prefix(GRID_WIDTH)
      .map { $0.position.distanceTo(point: point) }

    let closest = distances
      .map { ($0 - distances.min()!) / (distances.max()! - distances.min()!) }
      .enumerated()
      //.sorted( by: { $0.1 < $1.1 } )
      //.prefix(4)

    let idx = GRID_WIDTH * GRID_HEIGHT
    particles.append(Particle(position: point))
    particles[idx].immobile = true

    for (offset, distance) in closest {
      let particle = (GRID_WIDTH * (GRID_HEIGHT - 1)) + offset
      springs.append(Spring(
          a: particle,
          b: idx,
          offset: CGPoint(x: point.x - particles[particle].position.x, y: point.y - particles[particle].position.y),
          springK: springK * (1 - pow(distance, 1/2.5))
      ))
    }
    
    self.window.styleMask.remove(NSWindow.StyleMask.resizable)
  }

  @objc public func drag(at point: CGPoint) {
    if particles.indices.contains(GRID_WIDTH * GRID_HEIGHT) {
      particles[GRID_WIDTH * GRID_HEIGHT].position = point
    } else {
      // Very dirty workaround
      startDrag(at: NSEvent.mouseLocation)
      drag(at: point)
    }
  }

  @objc public func endDrag() {
    let idx = GRID_WIDTH * (GRID_HEIGHT - 1) + GRID_HEIGHT * (GRID_WIDTH - 1)
    springs.removeLast(springs.count - idx)
    if particles.indices.contains(GRID_WIDTH * GRID_HEIGHT) { particles.remove(at: GRID_WIDTH * GRID_HEIGHT) }

    if timer != nil { // Dont start a after-drag loop when there is already one running
      return
    }
    
    timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { (timer) in
      // when dragging during the after-drag loop, disable the loop
      if self.particles.indices.contains(GRID_WIDTH * GRID_HEIGHT) { return }

      self.step(delta: 1/60)
      self.window.drawWarp()
    }
  }

  @objc public func meshPoint(x: Int, y: Int) -> CGPointWarp {
    let position: CGPoint = CGVector(dx: x, dy: y).normalized * window.frame.size
    let particle = particles[convert(toIndex: x, y: (GRID_HEIGHT - 1) - y)]
    
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
