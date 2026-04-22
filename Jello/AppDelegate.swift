//
//  AppDelegate.swift
//  Jello
//
//  Created by Dennis Collaris on 22/07/2017.
//  Copyright © 2017 collaris. All rights reserved.
//


import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // macOS 26's OS-initiated drag pipeline clips CGSSetWindowWarp output
        // while the window is being moved. Disable OS drag so our event hook
        // in WindowAdditions can drive motion via setFrameOrigin, which is not
        // subject to that clip.
        for window in NSApp.windows {
            window.isMovable = false
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    
}
