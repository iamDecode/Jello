//
//  CGVector+Math.swift
//  Jello
//
//  Created by Dennis Collaris on 05/08/2018.
//  Copyright © 2018 collaris. All rights reserved.
//

extension CGVector {
  func add(vector: CGVector) -> CGVector {
    return CGVector(dx: self.dx + vector.dx, dy: self.dy + vector.dy)
  }

  func subtract(vector: CGVector) -> CGVector {
    return CGVector(dx: self.dx - vector.dx, dy: self.dy - vector.dy)
  }

  var normalized: CGVector {
    return CGVector(dx: self.dx / CGFloat(GRID_WIDTH-1), dy: self.dy / CGFloat(GRID_HEIGHT-1))
  }

  func scale(by factor: CGFloat) -> CGVector {
    return CGVector(dx: self.dx * factor, dy: self.dy * factor)
  }

  func multiply(size: CGSize) -> CGPoint {
    return CGPoint(x: self.dx * size.width, y: self.dy * size.height)
  }

  func multiply(size: CGSize) -> CGVector {
    return CGVector(dx: self.dx * size.width, dy: self.dy * size.height)
  }
}
