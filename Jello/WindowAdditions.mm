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

  [self.warp dragAt:NSEvent.mouseLocation];
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

@end
