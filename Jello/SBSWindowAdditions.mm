//
//  SBSWindowAdditions.m
//  removeme
//
//  Created by Dennis Collaris on 21/07/2017.
//  Copyright © 2017 example. All rights reserved.
//


#import "Cocoa/Cocoa.h"
#import <SpriteKit/SpriteKit.h>
#import "Jello-Swift.h"
#import <objc/runtime.h>

NSPoint GetWindowScreenOrigin(NSWindow* window) {
  NSRect window_frame = [window frame];
  NSRect screen_frame = [[window screen] frame];
  return NSMakePoint(NSMinX(window_frame),
                     NSHeight(screen_frame) - NSMaxY(window_frame));
}

void SetWindowAlpha(NSWindow* window, float alpha) {
  CGSConnection cid = _CGSDefaultConnection();
  CGSSetWindowAlpha(cid, [window windowNumber], alpha);
}

void SetWindowScale(NSWindow* window, float scale) {
  CGAffineTransform transform = CGAffineTransformIdentity;

  CGFloat scale_delta = 1.0 - scale;
  CGFloat cur_scale = 1.0 + scale_delta;
  transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(cur_scale, cur_scale));

  NSSize window_size = [window frame].size;
  CGFloat scale_offset_x = window_size.width * (1 - cur_scale) / 2.0;
  CGFloat scale_offset_y = window_size.height * (1 - cur_scale) / 2.0;

  NSPoint origin = GetWindowScreenOrigin(window);
  CGFloat new_x = -origin.x + scale_offset_x;
  CGFloat new_y = -origin.y + scale_offset_y;
  transform = CGAffineTransformTranslate(transform, new_x, new_y);

  CGSConnection cid = _CGSDefaultConnection();
  CGSSetWindowTransform(cid, [window windowNumber], transform);
}

void ClearWindowWarp(NSWindow* window) {
  CGSConnection cid = _CGSDefaultConnection();
  CGSSetWindowWarp(cid, [window windowNumber], 0, 0, NULL);
}

void SetWindowWarp(NSWindow* window, float y_offset, float scale, float perspective_offset) {
  const int W = 3;
  const int H = 3;

  CGSConnection cid = _CGSDefaultConnection();

  CGRect test = CGRectMake(0, 0, 0, 0);
  CGSGetWindowBounds(cid, [window windowNumber], &test);
  //  NSLog(@"%f", test.origin.x);
  //  NSLog(@"%f", test.origin.y);
  //  NSLog(@"%f", test.size.width);
  //  NSLog(@"%f", test.size.height);

  NSPoint origin = GetWindowScreenOrigin(window);
  CGFloat x = test.origin.x;
  CGFloat y = test.origin.y;
  CGFloat width = test.size.width;
  CGFloat height = test.size.height;
  CGFloat dst_width = width * scale;
  CGFloat dst_height = height * scale;

  CGFloat delta_x = (width - dst_width) / 2.0;
  CGFloat delta_y = (height - dst_height) / 2.0;
  x += delta_x;
  y += delta_y;

  CGFloat px1 = perspective_offset;
  CGFloat px2 = perspective_offset;

  CGPointWarp mesh[H][W] = {
    {
      {
        {0,  0},
        {static_cast<float>(0 + x),  static_cast<float>(0 + y)}
      },
      {
        {static_cast<float>(width/2),  0},
        {static_cast<float>((dst_width/2) + x),  static_cast<float>(0 + y)}
      },
      {
        {static_cast<float>(width),  0},
        {static_cast<float>(dst_width + x),  static_cast<float>(0 + y)}
      }
    },
    {
      {
        {0, static_cast<float>(height/2)},
        {static_cast<float>(0 + x),static_cast<float>((dst_height/2) + y)}
      },
      {
        {static_cast<float>(width/2),  static_cast<float>(height/2)},
        {static_cast<float>((dst_width/2) + x + 50),  static_cast<float>((dst_height/2) + y + 50)}
      },
      {
        {static_cast<float>(width), static_cast<float>(height/2)},
        {static_cast<float>(dst_width + x), static_cast<float>((dst_height/2) + y) }
      }
    },
    {
      {
        {0, static_cast<float>(height)},
        {static_cast<float>(0 + x),static_cast<float>(dst_height+ y)}
      },
      {
        {static_cast<float>(width/2),  static_cast<float>(height)},
        {static_cast<float>((dst_width/2) + x),  static_cast<float>(dst_height + y)}
      },
      {
        {static_cast<float>(width), static_cast<float>(height)},
        {static_cast<float>(dst_width + x), static_cast<float>(dst_height + y) }
      }
    }
  };


  CGSSetWindowWarp(cid, [window windowNumber], W, H, &(mesh[0][0]));
}

@interface WindowAnimation : NSAnimation {
@private
  NSWindow* window_;
}
@property(nonatomic,retain) NSWindow* window;
@end
@implementation WindowAnimation

@synthesize window = window_;

- (void)setCurrentProgress:(NSAnimationProgress)progress {
  [super setCurrentProgress:progress];

  if (progress >= 1.0) {
    ClearWindowWarp(window_);
    return;
  }

  float value = [self currentValue];
  float inverse_value = 1.0 - value;

  SetWindowAlpha(window_, value);
  CGFloat y_offset = 20 * inverse_value;
  CGFloat scale = 1.0 - 0.01 * inverse_value;
  CGFloat perspective_offset = ([window_ frame].size.width * 0.5) * inverse_value;

  SetWindowWarp(window_, y_offset, scale, perspective_offset);
}
@end

















@implementation NSWindow (SBSWindowAdditions)
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
  gWindowTrackingEnabled = bol;                // we have to use global variables (polluting global namespace)
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

  if (window.warp == NULL) {
    return;
  }
  
  [window.warp startDragAt: NSEvent.mouseLocation];
  perspective = 20.0f;
  gWindowTracking = YES;                    // the loop condition during tracking
  gWindowTrackingEventOrigin = [NSEvent mouseLocation];    // most accurate (somethings wrong with NSLeftMouseDragged events and their deltaX)
  [NSThread detachNewThreadSelector:@selector(windowMoves:) toTarget:(NSWindow*)[(NSNotification*)notification object] withObject:notification];
  // creating a new thread that is doing the monitoring of mouse movement
}

//static char WARP_KEY;

//- (void)setWarp:(NSObject *)property {
//  objc_setAssociatedObject(self, &WARP_KEY, property, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
//}
//
//- (NSObject*)warp {
//  return (NSObject*)objc_getAssociatedObject(self, &WARP_KEY);
//}



- (void) windowMoves:(id) notification {
  //NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];  // remember, we are in a new thread!

  NSRect startFrame = [self frame];              // where was the window prior to dragging
  gWindowTrackingCurrentWindowOrigin = startFrame.origin;    // where is it now

  while (gWindowTracking) {                  // polling for the mouse position until gWindowTracking is NO (see windowMoved:)
    gWindowTrackingCurrentWindowOrigin.x = startFrame.origin.x + [NSEvent mouseLocation].x - gWindowTrackingEventOrigin.x;
    gWindowTrackingCurrentWindowOrigin.y = startFrame.origin.y + [NSEvent mouseLocation].y - gWindowTrackingEventOrigin.y;
    // calculating the current window frame accordingly (size won't change)

    [self performSelectorOnMainThread:@selector(windowMoved:) withObject:notification waitUntilDone:YES];
    // lets do the main job on the main thread, particularly important for
    // querying the event stack for the mouseUp event signaling the end of the dragging
    // and posting the new event
  }

  //[pool release];                        // thread is dying, so we clean up
}


float perspective = 20.0f;
NSTimeInterval previousUpdate = 0.0;

- (void) windowMoved:(id) notification {            // to be performed on the main thread
  if (!NSEqualPoints(gWindowTrackingCurrentWindowOrigin, _frame.origin)) {
    // _frame is the private variable of an NSWindow, we have full access (category!)
    _frame.origin = gWindowTrackingCurrentWindowOrigin;    // setting the private instance variable so obersers of the windowDidMove notification
                                                           // can retrieve the current position by calling [[notification object] frame].
                                                           // The REAL setting of the frame will be done by the window server at the end of the drag
    [[NSNotificationCenter defaultCenter] postNotificationName:NSWindowDidMoveNotification object:self];
    // post the NSWindowDidMoveNotification (only if a move actually occured)
  }

  NSWindow* window = (NSWindow*)[(NSNotification*)notification object];
  if ([NSApp nextEventMatchingMask:NSEventMaskLeftMouseUp untilDate:nil inMode:NSEventTrackingRunLoopMode dequeue:NO]) {
    gWindowTracking = NO;                  // checking for an NSLeftMouseUp event that would indicate the end
                                           // of the dragging and set the looping condition accordingly.
                                           // MUY IMPORTANTE: we have to do this on the main thread!!!
    [window.warp endDrag];
  } else {
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    if (timestamp - previousUpdate < 0.01) {
      return;
    }

    float diff = timestamp - previousUpdate;

    [window.warp dragAt:NSEvent.mouseLocation];
    [self.warp stepWithDelta: diff];

    if (window.warp.force < 200.0f) {
      [self clearWarp];
    } else {
      [self drawWarp];
    }

    //[NSThread sleepForTimeInterval:0.01f]; // limit to max 33 fps
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

  CGSSetWindowWarp(cid, self.windowNumber, GRID_WIDTH, GRID_HEIGHT, &(mesh[0][0]));
}

- (void) clearWarp {
  ClearWindowWarp(self);
}



@end

