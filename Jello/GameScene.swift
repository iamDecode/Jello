//
//  GameScene.swift
//  Jello
//
//  Created by Dennis Collaris on 22/07/2017.
//  Copyright © 2017 collaris. All rights reserved.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {

  private var label : SKLabelNode?
  private var spinnyNode : SKShapeNode?
  var warp: Warp? = nil

  override func didMove(to view: SKView) {
    anchorPoint = CGPoint(x: 0, y: 0)

    // Get label node from scene and store it for use later
    self.label = self.childNode(withName: "//helloLabel") as? SKLabelNode
    if let label = self.label {
      label.alpha = 0.0
      label.run(SKAction.fadeIn(withDuration: 2.0))
    }

    var myWindow: NSWindow
    let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"),bundle: nil)
    let controller: NSWindowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "WindowController")) as! NSWindowController
    myWindow = controller.window!
    myWindow.makeKeyAndOrderFront(self)

    let warp = Warp(window: myWindow, scene: self)
    myWindow.warp = warp
    self.warp = warp
  }

//  var draggingParticle: Particle? = nil
//
//  func touchDown(atPoint pos : CGPoint) {
//    guard let warp = warp else { return }
//
//    for particles in warp.particles {
//      for particle in particles {
//        if particle.position.distanceTo(point: pos) < 20 {
//          draggingParticle = particle
//          particle.immobile = true
//          return
//        }
//      }
//    }
//  }
//
//  func touchMoved(toPoint pos : CGPoint) {
//    draggingParticle?.position = pos
//  }
//
//  func touchUp(atPoint pos : CGPoint) {
//    draggingParticle?.immobile = false
//    draggingParticle = nil
//  }
//
//  override func mouseDown(with event: NSEvent) {
//    self.touchDown(atPoint: event.location(in: self))
//  }
//
//  override func mouseDragged(with event: NSEvent) {
//    self.touchMoved(toPoint: event.location(in: self))
//  }
//
//  override func mouseUp(with event: NSEvent) {
//    self.touchUp(atPoint: event.location(in: self))
//  }
//
//  override func keyDown(with event: NSEvent) {
//    switch event.keyCode {
//    case 0x31:
//      if let label = self.label {
//        label.run(SKAction.init(named: "Pulse")!, withKey: "fadeInOut")
//      }
//    default:
//      print("keyDown: \(event.characters!) keyCode: \(event.keyCode)")
//    }
//  }
//
//
//  var timestamp: TimeInterval? = nil
  override func update(_ currentTime: TimeInterval) {
//    for particles in warp!.particles {
//      for particle in particles {
//        particle.draw()
//      }
//    }
//    if let t = timestamp {
//      warp?.step(delta: 0.05)
//
//    }
//
//    timestamp = currentTime
  }
}
