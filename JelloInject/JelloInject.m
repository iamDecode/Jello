//
//  JelloInject.m
//  JelloInject
//
//  Created by Dennis Collaris on 21/07/2017.
//  Copyright © 2017 collaris. All rights reserved.
//

#import "JelloInject.h"

static JelloInject* plugin = nil;

static void JelloDiag(NSString *msg) {
  NSString *line = [NSString stringWithFormat:@"[JelloInject pid=%d] %@\n", getpid(), msg];
  FILE *fp = fopen("/tmp/jello-inject.log", "a");
  if (!fp) return;
  fputs(line.UTF8String, fp);
  fflush(fp);
  fclose(fp);
}

@implementation JelloInject

#pragma mark SIMBL methods and loading

+ (JelloInject*)sharedInstance {
	if (plugin == nil)
		plugin = [[JelloInject alloc] init];
	
	return plugin;
}

+ (void)load {
  JelloDiag(@"+load fired");
  dispatch_async(dispatch_get_main_queue(), ^{
    [[JelloInject sharedInstance] loadPlugin];
  });
  JelloDiag(@"+load returning");
}

- (void)loadPlugin {
  NSArray *wins = [[NSApplication sharedApplication] windows];
  JelloDiag([NSString stringWithFormat:@"loadPlugin: %lu existing windows", (unsigned long)wins.count]);
  for (NSWindow *window in wins) {
    [self prepareWindow:window];
  }

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(windowDidBecomeKey:)
           name:NSWindowDidBecomeKeyNotification
         object:nil];
  JelloDiag(@"loadPlugin: registered NSWindowDidBecomeKeyNotification observer");
}

- (void)windowDidBecomeKey:(NSNotification *)note {
  [self prepareWindow:(NSWindow *)note.object];
}

- (void)prepareWindow:(NSWindow *)window {
  window.movable = NO;
  JelloDiag([NSString stringWithFormat:@"prepareWindow class=%@ movable=%d",
            NSStringFromClass([window class]), window.movable]);
}

@end
