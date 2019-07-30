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
#import "Jello-Swift.h"
#import <objc/runtime.h>

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

void SetWindowAlpha(NSWindow* window, float alpha) {
  CGSConnection cid = _CGSDefaultConnection();
  CGSSetWindowAlpha(cid, [window windowNumber], alpha);
}

void ClearWindowWarp(NSWindow* window) {
  CGSConnection cid = _CGSDefaultConnection();
  CGSSetWindowWarp(cid, [window windowNumber], 0, 0, NULL);
}






@implementation NSWindow (WindowAdditions)
@dynamic warp;

NSString const *key = @"warp";
- (void)setWarp:(Warp *)warp {
  objc_setAssociatedObject(self, &key, warp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (Warp *)warp {
  return objc_getAssociatedObject(self, &key);
}


+ (void)load {
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willMove:) name:NSWindowWillMoveNotification object:nil];
}

+ (void) willMove:(id) notification {
  NSWindow* window = (NSWindow*)[(NSNotification*)notification object];
  
  // Fallback for whatsapp and IDEA
  if (window.warp == NULL) {
    window.warp = [[Warp alloc] initWithWindow:window];
  }
  
  [window.warp startDragAt: NSEvent.mouseLocation];
  
  [NSThread detachNewThreadSelector:@selector(windowMoves:) toTarget:(NSWindow*)[(NSNotification*)notification object] withObject:notification];
}


id monitor;
- (void) windowMoves:(id) notification {
  NSWindow* window = (NSWindow*)[(NSNotification*)notification object];
  [self performSelectorOnMainThread:@selector(startMoveLoop:) withObject:notification waitUntilDone:YES];

  if (monitor != NULL) { // only disable mouseup monitor when we move a window again, because sometimes the first event does not fully trigger.
    [NSEvent removeMonitor:monitor];
  }

  monitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp handler:^(NSEvent *event) {
    [window moveStopped];
  }];
}

NSTimer *timer;
- (void) startMoveLoop: (id) notification {
  NSWindow* window = (NSWindow*)[(NSNotification*)notification object];
  timer = [NSTimer scheduledTimerWithTimeInterval:(1.0f / 60.0f) target:self selector:@selector(windowMoved:) userInfo:window repeats:YES];
}

NSTimeInterval previousUpdate = 0.0;

- (void) windowMoved:(NSTimer*) timer {
  NSWindow* window = [timer userInfo];
  NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
  float diff = timestamp - previousUpdate;

  [window.warp dragAt:NSEvent.mouseLocation];
  [self.warp stepWithDelta: diff];

  previousUpdate = timestamp;
}

- (void) moveStopped {
  [timer invalidate];
  timer = NULL;
  [self.warp endDrag];
}

- (void) drawWarp {
  CGSConnection cid = _CGSDefaultConnection();

//  CGRect bounds = NSZeroRect;
//  CGSGetWindowBounds(cid, CGSWindow(self.windowNumber), &bounds);
//  // TODO: should run this more often than the setwindowwarp. And subtract difference between window position (or mouse) and particle position.
//  CGSMoveWindow(cid, CGSWindow(self.windowNumber), &bounds.origin);
//
//  CGPointWarp pw = [self.warp meshPointWithX:0 y:0];
//  CGPoint point = CGPointMake(pw.global.x, pw.global.y);
//  CGSMoveWindow(cid, CGSWindow(self.windowNumber), &point);

  // normal grid
  int GRID_WIDTH = 8;
  int GRID_HEIGHT = 8;
  CGPointWarp mesh[GRID_HEIGHT][GRID_WIDTH];
  for (int y = 0; y < GRID_HEIGHT; y++) {
    for (int x = 0; x < GRID_WIDTH; x++) {
      mesh[y][x] = [self.warp meshPointWithX:x y:y];
    }
  }

  CGSSetWindowWarp(cid, CGSWindow(self.windowNumber), GRID_WIDTH, GRID_HEIGHT, &(mesh[0][0]));
}

- (void) clearWarp {
  ClearWindowWarp(self);
}

- (void) setAlpha: (float) alpha {
  CGSConnection cid = _CGSDefaultConnection();
  CGSSetWindowAlpha(cid, CGSWindow(self.windowNumber), alpha);
}



@end
