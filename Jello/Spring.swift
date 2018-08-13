//
//  Spring.swift
//  Jello
//
//  Created by Dennis Collaris on 05/08/2018.
//  Copyright © 2018 collaris. All rights reserved.
//

class Spring {
  var a: Int
  var b: Int
  var offset: CGPoint

  init(a: Int, b: Int, offset: CGPoint) {
    self.a = a
    self.b = b
    self.offset = offset
  }

  func apply(particles: inout [Particle]) -> [Particle] {
    let pa = particles[a].position
    let pb = particles[b].position

    let da = CGVector(dx: springK * 0.5 * (pb.x - pa.x - offset.x), dy: springK * 0.5 * (pb.y - pa.y - offset.y))
    let db = CGVector(dx: springK * 0.5 * (pa.x - pb.x + offset.x), dy: springK * 0.5 * (pa.y - pb.y + offset.y))

    particles[a].apply(force: da)
    particles[b].apply(force: db)
    
    return particles
  }
}

extension Collection where Element == Spring {
  func apply(particles: [Particle]) -> [Particle] {
    var particles = particles
    for spring in self {
      particles = spring.apply(particles: &particles)
    }
    
    return particles
  }
}
