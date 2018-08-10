//
//  Solver.swift
//  Jello
//
//  Created by Dennis Collaris on 09/08/2018.
//  Copyright © 2018 collaris. All rights reserved.
//

class Solver {
  func step(particles: [Particle], stepSize: CGFloat) {
    // Not implemented
  }

  func derivEval(particles: [Particle]) -> [Particle] {
    // Not implemented
    return []
  }
}


class Euler: Solver {
  override func step(particles: [Particle], stepSize: CGFloat) {
    let deriv = self.derivEval(particles: particles)

    for (i, particle) in particles.enumerated() {
      if particle.immobile { return }

      let k1 = deriv[i]
      particle.position += k1.velocity * stepSize
      particle.velocity += k1.acceleration * stepSize
    }
  }
}
