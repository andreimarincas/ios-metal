//
//  MetalView.h
//  Metal
//
//  Created by Andrei Marincas on 3/1/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

@protocol MetalViewDelegate;

@interface MetalView : UIView

@property (nonatomic, weak) id <MetalViewDelegate> delegate;

// The MTLDevice used to create Metal objects
@property (nonatomic, strong) id <MTLDevice> device;

// The drawable to be used for the current frame
@property (nonatomic, readonly) id <CAMetalDrawable> currentDrawable;

@property (nonatomic, readonly) CGSize drawableSize;

// Render pass descriptor from current drawable's texture
@property (nonatomic, readonly) MTLRenderPassDescriptor *renderPassDescriptor;

// Set these pixel formats to have the main drawable framebuffer get created with depth and/or stencil attachments
@property (nonatomic) MTLPixelFormat depthPixelFormat;
@property (nonatomic) MTLPixelFormat stencilPixelFormat;
@property (nonatomic) NSUInteger sampleCount;

// The clear color value used to generate the currentRenderPassDescriptor. Default is (0.0, 0.0, 0.0, 1.0) - black opaque.
@property (nonatomic) MTLClearColor clearColor;

// The pixelFormat for the drawable's texture
@property (nonatomic) MTLPixelFormat colorPixelFormat;

// Manually ask the view to draw new contents. This causes the view to call either the drawInMTKView (delegate) or drawRect (subclass) method.
// Call this on main thread
- (void)display;

@end

@protocol MetalViewDelegate <NSObject>

// Called whenever the drawableSize of the view will change
// Delegate can recompute view and projection matricies or regenerate any buffers to be compatible with the new view size or resolution
// size: New drawable size in pixels
- (void)metalView:(MetalView *)view drawableSizeWillChange:(CGSize)size;

// Called on the delegate when it is asked to render into the view
- (void)drawInMetalView:(MetalView *)view;

@end
