//
//  Spring.swift
//  Jello
//
//  Created by Dennis Collaris on 05/08/2018.
//  Copyright © 2018 collaris. All rights reserved.
//

import Foundation

class Spring {
  var a: Int
  var b: Int
  var offset: CGVector
  var springK: CGFloat

  init(a: Int, b: Int, offset: CGVector, springK: CGFloat) {
    self.a = a
    self.b = b
    self.offset = offset
    self.springK = springK
  }

  func apply(particles: inout [Particle]) {
    let pa = particles[a].position
    let pb = particles[b].position

    let da = CGVector(dx: springK * 0.5 * (pb.x - pa.x - offset.dx), dy: springK * 0.5 * (pb.y - pa.y - offset.dy))
    let db = CGVector(dx: springK * 0.5 * (pa.x - pb.x + offset.dx), dy: springK * 0.5 * (pa.y - pb.y + offset.dy))

    particles[a].apply(force: da)
    particles[b].apply(force: db)
  }
}

extension Collection where Element == Spring {
  func apply(particles: inout [Particle]) {
    for spring in self {
      spring.apply(particles: &particles)
    }
  }
}
