//
//  MetalRenderer.h
//  Metal
//
//  Created by Andrei Marincas on 3/1/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "MetalView.h"
#import "MetalViewController.h"
#import "Scene.h"

static const long kInFlightCommandBuffers = 3;

@interface MetalRenderer : NSObject <MetalViewDelegate, MetalViewControllerDelegate>

@property (nonatomic, weak) Scene *scene;

- (void)configure:(MetalView *)view;

@end
