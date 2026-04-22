//
//  SBSWindowAdditions.m
//  Jello
//
//  Created by Dennis Collaris on 21/07/2017.
//  Copyright © 2017 example. All rights reserved.
//

#import "WindowAdditions.h"
#import "Cocoa/Cocoa.h"
#import <SpriteKit/SpriteKit.h>
#import <objc/runtime.h>
#import "Jello-Swift.h"
#import "QuartzCore/QuartzCore.h"
#import "AppKit/AppKit.h"

#ifdef __cplusplus
extern "C" {
#endif
  extern CGError CGSSetWindowTransform(
                                       const CGSConnection cid,
                                       const CGSWindow wid,
                                       CGAffineTransform transform);
  
  extern CGError CGSSetWindowWarp(
                                  const CGSConnection cid,
                                  const CGSWindow wid,
                                  int w,
                                  int h,
                                  CGPointWarp* mesh);
  
  extern OSStatus CGSGetWindowBounds(const CGSConnection cid, const CGSWindow wid, CGRect *bounds);
  
  extern CGError CGSSetWindowAlpha(
                                   const CGSConnection cid,
                                   const CGSWindow wid,
                                   float alpha);
#ifdef __cplusplus
}
#endif


@implementation NSWindow (WindowAdditions)
@dynamic warp;

NSString const *key = @"warp";
- (void)setWarp:(Warp *)warp {
  objc_setAssociatedObject(self, &key, warp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (Warp *)warp {
  return objc_getAssociatedObject(self, &key);
}


// macOS 26 clips CGSSetWindowWarp output while the OS drag pipeline is active.
// AppDelegate sets isMovable=NO on our windows so that pipeline never engages;
// we drive motion ourselves from this local NSEvent monitor.
static NSWindow *g_dragWindow = nil;
static NSPoint   g_mouseStart;
static NSPoint   g_originStart;


+ (void)load {
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willMove:) name:NSWindowWillMoveNotification object:nil];

  [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp)
                                        handler:^NSEvent *(NSEvent *event) {
    if (event.type == NSEventTypeLeftMouseUp && g_dragWindow) {
      NSWindow *w = g_dragWindow;
      g_dragWindow = nil;
      [w moveStopped];
      return nil;
    }

    if (event.type == NSEventTypeLeftMouseDragged) {
      if (g_dragWindow) return nil;

      NSWindow *w = event.window;
      if (!w || w.isMovable) return event;
      NSRect content = [w contentRectForFrameRect:w.frame];
      if (event.locationInWindow.y < content.size.height) return event;

      g_dragWindow = w;
      g_mouseStart = NSEvent.mouseLocation;
      g_originStart = w.frame.origin;
      if (w.warp == nil) w.warp = [[Warp alloc] initWithWindow:w];
      [w.warp startDragAt:g_mouseStart];
      [w jelloBeginDrag];
      return nil;
    }

    return event;
  }];
}

+ (void) willMove:(id) notification {
  NSWindow* window = (NSWindow*)[(NSNotification*)notification object];
  if (window == g_dragWindow) return;
  
  // Fallback for whatsapp and IDEA
  if (window.warp == NULL) {
    window.warp = [[Warp alloc] initWithWindow:window];
  }
  
  [window.warp startDragAt: NSEvent.mouseLocation];
  [window windowMoves: notification];
}

id monitor;
CADisplayLink *displayLink;
- (void) windowMoves:(id) notification {
  NSWindow* window = (NSWindow*)[(NSNotification*)notification object];

  if (displayLink == NULL) {
    displayLink = [[NSScreen current] displayLinkWithTarget:self selector:@selector(windowMoved:)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
  }

//  if (monitor != NULL) { // only disable mouseup monitor when we move a window again, because sometimes the first event does not fully trigger.
//    [NSEvent removeMonitor:monitor];
//  }
  monitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp handler:^(NSEvent *event) {
    [window moveStopped];
  }];
}

- (void) jelloBeginDrag {
  if (displayLink == NULL) {
    displayLink = [[NSScreen current] displayLinkWithTarget:self selector:@selector(windowMoved:)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
  }
}

NSTimeInterval previousUpdate = 0.0;
- (void) windowMoved:(CADisplayLink*) displayLink {

  float diff;
  if (previousUpdate == 0.0) {
    diff = 1.0/60.0;
  } else {
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    diff = timestamp - previousUpdate;
    previousUpdate = timestamp;
  }

  NSPoint mouse = NSEvent.mouseLocation;
  if (g_dragWindow == self) {
    [self setFrameOrigin:NSMakePoint(
      g_originStart.x + (mouse.x - g_mouseStart.x),
      g_originStart.y + (mouse.y - g_mouseStart.y))];
  }

  [self.warp dragAt:mouse];
  [self.warp stepWithDelta: diff];
}

- (void) moveStopped {
  if (displayLink != NULL) {
    [displayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    displayLink = NULL;
  }
  [self.warp endDrag];
}

- (void) drawWarp {
  CGSConnection cid = _CGSDefaultConnection();

  // normal grid
  int GRID_WIDTH = 8;
  int GRID_HEIGHT = 6;
  CGPointWarp mesh[GRID_HEIGHT][GRID_WIDTH];
  for (int y = 0; y < GRID_HEIGHT; y++) {
    for (int x = 0; x < GRID_WIDTH; x++) {
      mesh[y][x] = [self.warp meshPointWithX:x y:y];
    }
  }

  CGSSetWindowWarp(cid, CGSWindow(self.windowNumber), GRID_WIDTH, GRID_HEIGHT, &(mesh[0][0]));
}

- (void) setFrameDirty:(NSRect) frame {
    [self setFrame:frame display:NO];
    self.viewsNeedDisplay = false;
    CGSConnection cid = _CGSDefaultConnection();
    CGSSetWindowWarp(cid, CGSWindow([self windowNumber]), 0, 0, NULL);
    self.viewsNeedDisplay = false;
}

- (void) resetWarp {
  CGSConnection cid = _CGSDefaultConnection();
  CGSSetWindowWarp(cid, CGSWindow([self windowNumber]), 0, 0, NULL);
}

@end
