//
//  MetalRenderer.h
//  Metal01
//
//  Created by Andrei Marincas on 3/1/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "MetalView.h"
#import "MetalViewController.h"

@interface MetalRenderer : NSObject <MetalViewDelegate, MetalViewControllerDelegate>

- (void)configure:(MetalView *)view;

@end
