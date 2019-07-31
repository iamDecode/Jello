//
//  SBSWindowAdditions.h
//  JelloInject
//
//  Created by Dennis Collaris on 21/07/2017.
//  Copyright © 2017 collaris. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#ifdef __cplusplus
extern "C" {
#endif
  typedef int CGSWindow;
  typedef int CGSConnection;
  
  extern CGSConnection _CGSDefaultConnection();
  
  typedef struct {
    float x;
    float y;
  } MeshPoint;
  
  typedef struct {
    MeshPoint local;
    MeshPoint global;
  } CGPointWarp;
#ifdef __cplusplus
}
#endif

@class Warp;

@interface NSWindow (WindowAdditions)
@property (retain, nonatomic) Warp *warp;

- (void) drawWarp;
- (void) setFrameDirty:(NSRect) frame;

@end
