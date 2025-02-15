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

    var da = CGVector(dx: springK * 0.5 * (pb.x - pa.x - offset.dx), dy: springK * 0.5 * (pb.y - pa.y - offset.dy))
    var db = CGVector(dx: springK * 0.5 * (pa.x - pb.x + offset.dx), dy: springK * 0.5 * (pa.y - pb.y + offset.dy))

    if (!particles[a].immobile && particles[b].immobile) { da = CGVector(dx: da.dx * 2, dy: da.dy * 2) }
    if (particles[a].immobile && !particles[b].immobile) { db = CGVector(dx: db.dx * 2, dy: db.dy * 2) }
    if (particles[a].immobile && particles[b].immobile) { return }

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
