//
//  Solver.swift
//  Jello
//
//  Created by Dennis Collaris on 09/08/2018.
//  Copyright © 2018 collaris. All rights reserved.
//

class Solver {
  let warp: Warp
  
  @objc var velocity: CGFloat = 0
  @objc var force: CGFloat = 0
  
  init(warp: Warp) {
    self.warp = warp
  }
  
  func step(particles: inout [Particle], stepSize: CGFloat) {
    // Not implemented
  }

  func derivEval(particles: [Particle]) -> [Particle] {
    var particles = particles
    
    // Clear forces
    for i in 0..<particles.count {
      particles[i].force = CGVector.zero
    }
    
    // Apply friction
    for i in 0..<particles.count {
      particles[i].force -= particles[i].velocity * friction
    }
    
    // Apply spring forces
    particles = warp.springs.apply(particles: particles)
    
    self.velocity = particles.reduce(0) { (a,b) in a + abs(b.velocity.dx) + abs(b.velocity.dy)}
    self.force = particles.reduce(0) { (a,b) in a + abs(b.force.dx) + abs(b.force.dy)}
    
    return particles
  }
}


class Euler: Solver {
  override func step(particles: inout [Particle], stepSize: CGFloat) {
    let deriv = self.derivEval(particles: particles)

    for i in 0..<particles.count {
      if particles[i].immobile {
        particles[i].velocity = CGVector.zero
        particles[i].force = CGVector.zero
        return
      }

      let k1 = deriv[i]
      if k1.velocity.dx.isNaN {
        print("tsar")
      }
      
      particles[i].velocity += k1.acceleration * stepSize
      particles[i].position += k1.velocity * stepSize
    }
  }
}
