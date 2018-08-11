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
  [self setLiveFrameTracking: YES];
}

+ (void) setLiveFrameTracking:(BOOL) bol {
  gWindowTrackingEnabled = bol;
  if (bol) {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willMove:) name:NSWindowWillMoveNotification object:nil];
    // getting informed as soon as any window is dragged
  }
  else {
    gWindowTracking = NO;                  // like this, applications can interrupt even ongoing frame tracking
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillMoveNotification object:nil];
  }
}

+ (BOOL) isLiveFrameTracking {
  return gWindowTrackingEnabled;
}

+ (void) willMove:(id) notification {
  NSWindow* window = (NSWindow*)[(NSNotification*)notification object];
  
  // Fallback for whatsapp and IDEA
  if (window.warp == NULL) {
    window.warp = [[Warp alloc] initWithWindow:window];
  }
  
  [window.warp startDragAt: NSEvent.mouseLocation];
  gWindowTracking = YES;
  
  [NSThread detachNewThreadSelector:@selector(windowMoves:) toTarget:(NSWindow*)[(NSNotification*)notification object] withObject:notification];
}


- (void) windowMoves:(id) notification {
  while (gWindowTracking) {
    [self performSelectorOnMainThread:@selector(windowMoved:) withObject:notification waitUntilDone:YES];
  }
}

NSTimeInterval previousUpdate = 0.0;

- (void) windowMoved:(id) notification {
  NSWindow* window = (NSWindow*)[(NSNotification*)notification object];
  if ([NSApp nextEventMatchingMask:NSEventMaskLeftMouseUp untilDate:nil inMode:NSEventTrackingRunLoopMode dequeue:NO]) {
    gWindowTracking = NO;
    [window.warp endDrag];
  } else {
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    if (timestamp - previousUpdate < 1/60) {
      return;
    }
    
    float diff = timestamp - previousUpdate;
    
    [window.warp dragAt:NSEvent.mouseLocation];
    [self.warp stepWithDelta: diff];
    
    [self drawWarp];

    [NSThread sleepForTimeInterval:0.0083f]; // sleep to prevent very quick while loop
    previousUpdate = timestamp;
  }
}

- (void) drawWarp {
  CGSConnection cid = _CGSDefaultConnection();
  
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



@end
