//
//  Spring.swift
//  Jello
//
//  Created by Dennis Collaris on 05/08/2018.
//  Copyright © 2018 collaris. All rights reserved.
//

class Spring {
  var a: Particle
  var b: Particle
  var offset: CGPoint

  init(a: Particle, b: Particle, offset: CGPoint) {
    self.a = a
    self.b = b
    self.offset = offset
  }

  func apply() {
    let pa = a.position
    let pb = b.position

    let da = CGVector(dx: springK * 0.5 * (pb.x - pa.x - offset.x), dy: springK * 0.5 * (pb.y - pa.y - offset.y))
    let db = CGVector(dx: springK * 0.5 * (pa.x - pb.x + offset.x), dy: springK * 0.5 * (pa.y - pb.y + offset.y))

    a.apply(force: da)
    b.apply(force: db)
  }
}

extension Collection where Element == Spring {
  func apply() {
    for spring in self {
      spring.apply()
    }
  }
}

class SKSpring: Spring {
  var shape: SKShapeNode
  var scene: SKScene

  init(a: Particle, b: Particle, offset: CGPoint, scene: SKScene) {
    self.scene = scene

    shape = SKShapeNode()
    shape.path = createPath(for: [a.position, b.position])
    shape.strokeColor = NSColor.init(white: 1, alpha: 0.5)
    shape.lineWidth = 2
    scene.addChild(shape)

    super.init(a: a, b: b, offset: offset)

    draw()
  }

  deinit {
    shape.removeFromParent()
  }

  func draw() {
    let path = createPath(for: [a.position, b.position])
    shape.path = path
  }
}

extension Collection where Element == SKSpring {
  func apply() {
    for spring in self {
      spring.apply()
    }
  }
}
