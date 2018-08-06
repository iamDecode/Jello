//
//  CGPoint+Math.swift
//  Jello
//
//  Created by Dennis Collaris on 05/08/2018.
//  Copyright © 2018 collaris. All rights reserved.
//

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
