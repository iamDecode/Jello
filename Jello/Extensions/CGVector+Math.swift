//
//  CGVector+Math.swift
//  Jello
//
//  Created by Dennis Collaris on 05/08/2018.
//  Copyright © 2018 collaris. All rights reserved.
//

import Foundation

extension CGVector {
  var normalized: CGVector {
    return CGVector(dx: self.dx / CGFloat(GRID_WIDTH-1), dy: self.dy / CGFloat(GRID_HEIGHT-1))
  }
}

public func + (left: CGVector, right: CGVector) -> CGVector {
  return CGVector(dx: left.dx + right.dx, dy: left.dy + right.dy)
}

public func += (left: inout CGVector, right: CGVector) {
  left = left + right
}

public func - (left: CGVector, right: CGVector) -> CGVector {
  return CGVector(dx: left.dx - right.dx, dy: left.dy - right.dy)
}

public func -= (left: inout CGVector, right: CGVector) {
  left = left - right
}

public func + (left: CGVector, right: CGPoint) -> CGVector {
  return CGVector(dx: left.dx + right.x, dy: left.dy + right.y)
}

public func += (left: inout CGVector, right: CGPoint) {
  left = left + right
}

public func - (left: CGVector, right: CGPoint) -> CGVector {
  return CGVector(dx: left.dx - right.x, dy: left.dy - right.y)
}

public func -= (left: inout CGVector, right: CGPoint) {
  left = left - right
}

public func * (left: CGVector, right: CGVector) -> CGVector {
  return CGVector(dx: left.dx * right.dx, dy: left.dy * right.dy)
}

public func *= (left: inout CGVector, right: CGVector) {
  left = left * right
}

public func * (vector: CGVector, scalar: CGFloat) -> CGVector {
  return CGVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
}

public func *= (vector: inout CGVector, scalar: CGFloat) {
  vector = vector * scalar
}

public func * (vector: CGVector, size: CGSize) -> CGVector {
  return CGVector(dx: vector.dx * size.width, dy: vector.dy * size.height)
}

public func * (vector: CGVector, size: CGSize) -> CGPoint {
  return CGPoint(x: vector.dx * size.width, y: vector.dy * size.height)
}

public func / (left: CGVector, right: CGVector) -> CGVector {
  return CGVector(dx: left.dx / right.dx, dy: left.dy / right.dy)
}

public func /= (left: inout CGVector, right: CGVector) {
  left = left / right
}

public func / (vector: CGVector, scalar: CGFloat) -> CGVector {
  return CGVector(dx: vector.dx / scalar, dy: vector.dy / scalar)
}

public func /= (vector: inout CGVector, scalar: CGFloat) {
  vector = vector / scalar
}

public func / (vector: CGVector, size: CGSize) -> CGVector {
  return CGVector(dx: vector.dx / size.width, dy: vector.dy / size.height)
}

public func /= (vector: inout CGVector, size: CGSize) {
  vector = vector / size
}
