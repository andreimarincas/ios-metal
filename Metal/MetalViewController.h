//
//  MetalViewController.h
//  Metal01
//
//  Created by Andrei Marincas on 3/1/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MetalViewController : UIViewController

// Pause/resume the render loop
@property (nonatomic, getter=isPaused) BOOL paused;

@end

@protocol MetalViewControllerDelegate <NSObject>

// Called from the thread the main game loop is run
- (void)update:(MetalViewController *)controller;

// Called whenever the main game loop is paused, such as when the app is backgrounded
- (void)viewController:(MetalViewController *)controller willPause:(BOOL)pause;

@end
