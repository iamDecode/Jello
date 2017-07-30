//
//  SBSWindowAdditions.h
//  removeme
//
//  Created by Dennis Collaris on 21/07/2017.
//  Copyright © 2017 example. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#ifdef __cplusplus
extern "C" {
#endif
  typedef int CGSWindow;
  typedef int CGSConnection;

  extern CGSConnection _CGSDefaultConnection();

  extern CGError CGSSetWindowTransform(
                                       const CGSConnection cid,
                                       const CGSWindow wid,
                                       CGAffineTransform transform);

  typedef struct {
    float x;
    float y;
  } MeshPoint;

  typedef struct {
    MeshPoint local;
    MeshPoint global;
  } CGPointWarp;

  //typedef CGPointWarp CGMeshWarp[4][4];

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

static BOOL gWindowTrackingEnabled = YES;
static BOOL gWindowTracking = YES;
static NSPoint gWindowTrackingEventOrigin, gWindowTrackingCurrentWindowOrigin;

@class Warp;

@interface NSWindow (SBSWindowAdditions)
@property (weak, nonatomic) Warp *warp;

- (void) drawWarp;
- (void) clearWarp;
+ (void) setLiveFrameTracking:(BOOL) bol;
+ (BOOL) isLiveFrameTracking;

@end

