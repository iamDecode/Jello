//
//  JelloInject.m
//  JelloInject
//
//  Created by Dennis Collaris on 21/07/2017.
//  Copyright © 2017 collaris. All rights reserved.
//

#import "JelloInject.h"
#import "Jello-Swift.h"
#import "WindowAdditions.h"

static JelloInject* plugin = nil;

@implementation JelloInject

#pragma mark SIMBL methods and loading

+ (JelloInject*)sharedInstance {
	if (plugin == nil)
		plugin = [[JelloInject alloc] init];
	
	return plugin;
}

+ (void)load {
	[[JelloInject sharedInstance] loadPlugin];
	
	NSLog(@"JelloInject loaded.");
}

- (void)loadPlugin {
  for (NSWindow *window in [[NSApplication sharedApplication] windows]) {
    Warp *warp = [[Warp alloc] initWithWindow:window];
    window.warp = warp;
  }
}

@end
