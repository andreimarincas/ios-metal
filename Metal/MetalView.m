//
//  MetalView.m
//  Metal
//
//  Created by Andrei Marincas on 3/1/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import "MetalView.h"

@interface MetalView ()
{
    __weak CAMetalLayer *_metalLayer;
    
    BOOL _layerSizeDidUpdate;
}

@end

@implementation MetalView

@synthesize device = _device;
@synthesize currentDrawable = _currentDrawable;
@synthesize currentRenderPassDescriptor = _renderPassDescriptor;

+ (Class)layerClass
{
    return [CAMetalLayer class];
}

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        [self commonInit];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self)
    {
        [self commonInit];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        [self commonInit];
    }
    
    return self;
}

- (void)commonInit
{
    self.opaque = YES;
    self.backgroundColor = nil;
    
    // Find a usable device
    _device = MTLCreateSystemDefaultDevice();
    
    if (!_device)
    {
        NSLog(@"ERROR: Metal is not supported on this device");
        assert(0);
    }
    
    _metalLayer = (CAMetalLayer *)self.layer;
    _metalLayer.device = _device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    // This is the default but if we wanted to perform compute on the final rendering layer we could set this to no
    _metalLayer.framebufferOnly = YES;
    
    _clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
}

- (void)didMoveToWindow
{
    self.contentScaleFactor = self.window.screen.nativeScale;
}

- (void)setContentScaleFactor:(CGFloat)contentScaleFactor
{
    [super setContentScaleFactor:contentScaleFactor];
    _layerSizeDidUpdate = YES;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _layerSizeDidUpdate = YES;
}

#pragma mark

- (void)setDevice:(id <MTLDevice>)device
{
    [_metalLayer setDevice:device];
}

- (id <MTLDevice>)device
{
    return [_metalLayer device];
}

- (id <CAMetalDrawable>)currentDrawable
{
    if (!_currentDrawable)
    {
        _currentDrawable = [_metalLayer nextDrawable];
    }
    
    return _currentDrawable;
}

- (MTLRenderPassDescriptor *)currentRenderPassDescriptor
{
    id <CAMetalDrawable> drawable = self.currentDrawable;
    
    if (!drawable)
    {
        NSLog(@"ERROR: Failed to get a drawable!");
        _renderPassDescriptor = nil;
    }
    else
    {
        [self setupRenderPassDescriptorForTexture:drawable.texture];
    }
    
    return _renderPassDescriptor;
}

- (void)setupRenderPassDescriptorForTexture:(id <MTLTexture>)texture
{
    // Create lazily
    if (!_renderPassDescriptor)
    {
        _renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    }
    
    // Create a color attachment every frame since we have to recreate the texture every frame
    MTLRenderPassColorAttachmentDescriptor *colorAttachment = _renderPassDescriptor.colorAttachments[0];
    colorAttachment.texture = texture;
    
    // Make sure to clear every frame for best performance
    colorAttachment.loadAction = MTLLoadActionClear;
    colorAttachment.clearColor = self.clearColor;
    
    // Store only attachments that will be presented to the screen, as in this case
    colorAttachment.storeAction = MTLStoreActionStore;
}

- (void)display
{
    // Create autorelease pool per frame to avoid possible deadlock situations
    // because there are 3 CAMetalDrawables sitting in an autorelease pool.
    @autoreleasepool
    {
        // Handle display changes here
        
        if (_layerSizeDidUpdate)
        {
            // Set the metal layer to the drawable size in case orientation or size changes
            CGSize drawableSize = self.bounds.size;
            
            // Scale drawableSize so that drawable is 1:1 width pixels not 1:1 to points
            
            UIScreen *screen = self.window.screen ?: [UIScreen mainScreen]; // the screen property of the UIWindow can be nil during some backgrounding/foregrounding situations
            drawableSize.width *= screen.nativeScale;
            drawableSize.height *= screen.nativeScale;
            
            // Rendering delegate method to ask renderer to draw this frame's content
            [self.delegate metalView:self drawableSizeWillChange:drawableSize];
            
            _metalLayer.drawableSize = drawableSize;
            
            _layerSizeDidUpdate = NO;
        }
        
        // Rendering delegate method to ask renderer to draw this frame's content
        [self.delegate drawInMetalView:self];
        
        // Do not retain current drawable beyond the frame.
        // There should be no strong references to this object outside of this view class
        _currentDrawable = nil;
    }
}

@end
