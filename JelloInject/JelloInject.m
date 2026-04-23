//
//  JelloInject.m
//  JelloInject
//
//  Created by Dennis Collaris on 21/07/2017.
//  Copyright © 2017 collaris. All rights reserved.
//

#import "JelloInject.h"
#import "WindowAdditions.h"

static JelloInject *plugin = nil;
static id g_becomeKeyObserver = nil;
static BOOL g_initialized = NO;

static void JelloDiag(NSString *msg) {
  NSString *line = [NSString stringWithFormat:@"[JelloInject pid=%d] %@\n", getpid(), msg];
  FILE *fp = fopen("/tmp/jello-inject.log", "a");
  if (!fp) return;
  fputs(line.UTF8String, fp);
  fflush(fp);
  fclose(fp);
}

extern void JelloSetupDragHooks(void);
extern void JelloTeardownDragHooks(void);

void JelloInjectInit(void);
void JelloInjectTeardown(void);

@interface JelloInject ()
+ (JelloInject*)sharedInstance;
- (void)loadPlugin;
- (void)unloadPlugin;
@end

@implementation JelloInject

+ (JelloInject*)sharedInstance {
  if (plugin == nil) plugin = [[JelloInject alloc] init];
  return plugin;
}

+ (void)load {
  JelloInjectInit();
}

- (void)loadPlugin {
  if (g_initialized) { JelloDiag(@"loadPlugin: already initialized"); return; }
  g_initialized = YES;

  JelloSetupDragHooks();

  NSArray *wins = [[NSApplication sharedApplication] windows];
  JelloDiag([NSString stringWithFormat:@"loadPlugin: %lu windows", (unsigned long)wins.count]);
  for (NSWindow *window in wins) {
    window.movable = NO;
  }

  g_becomeKeyObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:NSWindowDidBecomeKeyNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
    NSWindow *w = (NSWindow *)note.object;
    if (w) w.movable = NO;
  }];
  JelloDiag(@"loadPlugin: hooks installed");
}

- (void)unloadPlugin {
  if (!g_initialized) { JelloDiag(@"unloadPlugin: not initialized"); return; }
  g_initialized = NO;

  if (g_becomeKeyObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:g_becomeKeyObserver];
    g_becomeKeyObserver = nil;
  }

  JelloTeardownDragHooks();

  for (NSWindow *window in [[NSApplication sharedApplication] windows]) {
    if ([window respondsToSelector:@selector(moveStopped)]) {
      [window moveStopped];
    }
    window.movable = YES;
    if ([window respondsToSelector:@selector(resetWarp)]) {
      [window resetWarp];
    }
  }
  JelloDiag(@"unloadPlugin: done");
}

@end

void JelloInjectInit(void) {
  JelloDiag(@"JelloInjectInit called");
  dispatch_async(dispatch_get_main_queue(), ^{
    [[JelloInject sharedInstance] loadPlugin];
  });
}

void JelloInjectTeardown(void) {
  JelloDiag(@"JelloInjectTeardown called");
  dispatch_async(dispatch_get_main_queue(), ^{
    [[JelloInject sharedInstance] unloadPlugin];
  });
}
