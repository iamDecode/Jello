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


@interface NSWindow (WindowAdditionsInternal)
+ (void)willMove:(id)notification;
+ (void)didMove:(NSNotification *)note;
- (void)windowMoves:(id)notification;
- (void)windowMoved:(CADisplayLink *)displayLink;
- (void)jelloBeginDrag;
@end

@implementation NSWindow (WindowAdditions)
@dynamic warp;

NSString const *key = @"warp";
- (void)setWarp:(Warp *)warp {
  objc_setAssociatedObject(self, &key, warp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (Warp *)warp {
  return objc_getAssociatedObject(self, &key);
}


// Two independent drag detection paths coexist:
//
//   A) Title-bar drag on standard NSWindow apps (Illustrator, TextEdit, …).
//      The local LeftMouseDragged monitor intercepts the event BEFORE the OS
//      drag pipeline engages, driving motion ourselves via setFrameOrigin.
//      This is the only path that works on macOS 26 for apps that use the
//      OS drag pipeline — the pipeline clips CGSSetWindowWarp output while
//      active, so we must bypass it.
//
//   B) Programmatic drag on Electron / Chromium / custom-chrome apps
//      (FreeTube, Teams, VS Code, …). These apps call setFrame: themselves
//      from Chromium's mouseDown handler — the OS drag pipeline is never
//      involved and `isMovable` has no effect. We detect drag-via-setFrame
//      by observing NSWindowDidMoveNotification while the left mouse button
//      is held down.
static NSWindow *g_dragWindow = nil;
static BOOL      g_ownsMotion = NO;     // YES for path A, NO for path B
static BOOL      g_leftMouseDown = NO;
static NSPoint   g_mouseStart;
static NSPoint   g_originStart;
static id        g_globalMouseUpMonitor = nil;
static id        g_localEventMonitor = nil;
static BOOL      g_hooksInitialized = NO;


static void jelloEndActiveDrag() {
  if (!g_dragWindow) return;
  NSWindow *w = g_dragWindow;
  g_dragWindow = nil;
  g_ownsMotion = NO;
  [w moveStopped];
  if (g_globalMouseUpMonitor) {
    [NSEvent removeMonitor:g_globalMouseUpMonitor];
    g_globalMouseUpMonitor = nil;
  }
}


extern "C" void JelloSetupDragHooks(void) {
  if (g_hooksInitialized) return;
  g_hooksInitialized = YES;

  [[NSNotificationCenter defaultCenter] addObserver:[NSWindow class]
                                           selector:@selector(willMove:)
                                               name:NSWindowWillMoveNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:[NSWindow class]
                                           selector:@selector(didMove:)
                                               name:NSWindowDidMoveNotification
                                             object:nil];

  g_localEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskLeftMouseDown
                                                                       | NSEventMaskLeftMouseDragged
                                                                       | NSEventMaskLeftMouseUp)
                                                              handler:^NSEvent *(NSEvent *event) {
    if (event.type == NSEventTypeLeftMouseDown) {
      g_leftMouseDown = YES;
      return event;
    }

    if (event.type == NSEventTypeLeftMouseUp) {
      g_leftMouseDown = NO;
      BOOL wasOwned = g_ownsMotion;
      jelloEndActiveDrag();
      // Owned drags consume the mouse-up (we've been returning drag events
      // as nil, so letting mouse-up through would drop selection/focus
      // state). Path-B drags (app-owned motion) must pass through so the
      // app can run its own end-of-drag logic.
      return wasOwned ? nil : event;
    }

    // LeftMouseDragged
    if (g_dragWindow) {
      // A path-A drag in flight — continue consuming so the OS doesn't
      // also try to drag. For path-B, let the app see the events.
      return g_ownsMotion ? nil : event;
    }

    NSWindow *w = event.window;
    if (!w) return event;
    NSRect content = [w contentRectForFrameRect:w.frame];
    // Only treat drags that start in the title-bar strip as path-A.
    // For fullSize-content / borderless / Electron frameless windows
    // content.height == frame.height, so this check naturally skips them
    // and they'll fall through to path B via didMove:.
    if (event.locationInWindow.y < content.size.height) return event;

    g_dragWindow = w;
    g_ownsMotion = YES;
    g_mouseStart = NSEvent.mouseLocation;
    g_originStart = w.frame.origin;
    if (w.warp == nil) w.warp = [[Warp alloc] initWithWindow:w];
    [w.warp startDragAt:g_mouseStart];
    [w jelloBeginDrag];
    NSLog(@"[Jello] path A drag start on %@", w);
    return nil;
  }];
}

extern "C" void JelloTeardownDragHooks(void) {
  if (!g_hooksInitialized) return;
  g_hooksInitialized = NO;

  if (g_localEventMonitor) {
    [NSEvent removeMonitor:g_localEventMonitor];
    g_localEventMonitor = nil;
  }
  if (g_globalMouseUpMonitor) {
    [NSEvent removeMonitor:g_globalMouseUpMonitor];
    g_globalMouseUpMonitor = nil;
  }
  [[NSNotificationCenter defaultCenter] removeObserver:[NSWindow class]
                                                  name:NSWindowWillMoveNotification
                                                object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:[NSWindow class]
                                                  name:NSWindowDidMoveNotification
                                                object:nil];
  jelloEndActiveDrag();
}

+ (void)load {
  JelloSetupDragHooks();
}

+ (void)didMove:(NSNotification *)note {
  if (!g_leftMouseDown) return;             // programmatic move, not a drag
  NSWindow *w = (NSWindow *)note.object;
  if (!w) return;
  if (g_dragWindow == w) return;            // already handling this window
  if (g_dragWindow) return;                 // another window already dragging

  g_dragWindow = w;
  g_ownsMotion = NO;                        // app drives motion; we only wobble
  if (w.warp == nil) w.warp = [[Warp alloc] initWithWindow:w];
  [w.warp startDragAt:NSEvent.mouseLocation];
  [w jelloBeginDrag];
  NSLog(@"[Jello] path B drag start on %@", w);

  // Mouse-up might land outside this app (e.g. over the dock) — catch it too.
  g_globalMouseUpMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseUp
                                                                  handler:^(NSEvent *event) {
    g_leftMouseDown = NO;
    jelloEndActiveDrag();
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
  if (g_dragWindow == self && g_ownsMotion) {
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
