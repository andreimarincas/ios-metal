//
//  MetalView.mm
//  Metal
//
//  Created by Andrei Marincas on 3/1/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import "MetalView.h"

@implementation MetalView
{
     // Using ivars instead of properties to avoid any performance penalities with the Objective-C runtime.
    
    __weak CAMetalLayer *_metalLayer;
    
    BOOL _layerSizeDidUpdate;
    
    id <MTLTexture> _depthTex;
    id <MTLTexture> _stencilTex;
    id <MTLTexture> _msaaTex; // multisample anti-aliasing
}

@synthesize currentDrawable = _currentDrawable;
@synthesize renderPassDescriptor = _renderPassDescriptor;

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

#pragma mark -

- (void)setDevice:(id<MTLDevice>)device
{
    if (_device != device)
    {
        _device = device;
        [_metalLayer setDevice:device];
        _currentDrawable = nil;
    }
}

- (id <CAMetalDrawable>)currentDrawable
{
    if (!_currentDrawable)
    {
        _currentDrawable = [_metalLayer nextDrawable];
    }
    
    return _currentDrawable;
}

- (CGSize)drawableSize
{
    id <CAMetalDrawable> drawable = self.currentDrawable;
    return CGSizeMake(drawable.texture.width, drawable.texture.height);
}

- (MTLRenderPassDescriptor *)renderPassDescriptor
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
    
    // If sample count is greater than 1, render into using MSAA, then resolve into our color texture
    if (_sampleCount > 1)
    {
        BOOL doUpdate = (_msaaTex.width != texture.width) || (_msaaTex.height != texture.height) || (_msaaTex.sampleCount != _sampleCount);
        
        if (!_msaaTex || (_msaaTex && doUpdate))
        {
            MTLTextureDescriptor *msaaTexDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm
                                                                                                   width: texture.width
                                                                                                  height: texture.height
                                                                                               mipmapped: NO];
            msaaTexDesc.textureType = MTLTextureType2DMultisample;
            
            // Sample count was specified to the view by the renderer.
            // This must match the sample count given to any pipeline state using this render pass descriptor.
            msaaTexDesc.sampleCount = _sampleCount;
            
            _msaaTex = [_device newTextureWithDescriptor:msaaTexDesc];
        }
        
        // When multisampling, perform rendering to _msaaTex, then resolve
        // to 'texture' at the end of the scene
        colorAttachment.texture = _msaaTex;
        colorAttachment.resolveTexture = texture;
        
        // Set store action to resolve in this case
        colorAttachment.storeAction = MTLStoreActionMultisampleResolve;
    }
    else
    {
        // Store only attachments that will be presented to the screen, as in this case
        colorAttachment.storeAction = MTLStoreActionStore;
    } // color0
    
    // Create the depth and stencil attachments
    
    if (_depthPixelFormat != MTLPixelFormatInvalid)
    {
        BOOL doUpdate = (_depthTex.width != texture.width) || (_depthTex.height != texture.height) || (_depthTex.sampleCount != _sampleCount);
        
        if (!_depthTex || doUpdate)
        {
            //  If we need a depth texture and don't have one, or if the depth texture we have is the wrong size
            //  then allocate one of the proper size
            MTLTextureDescriptor *depthTexDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: _depthPixelFormat
                                                                                                    width: texture.width
                                                                                                   height: texture.height
                                                                                                mipmapped: NO];
            
            depthTexDesc.textureType = (_sampleCount > 1) ? MTLTextureType2DMultisample : MTLTextureType2D;
            depthTexDesc.sampleCount = _sampleCount;
            depthTexDesc.usage = MTLTextureUsageUnknown;
            depthTexDesc.storageMode = MTLStorageModePrivate;
            
            _depthTex = [_device newTextureWithDescriptor:depthTexDesc];
            
            MTLRenderPassDepthAttachmentDescriptor *depthAttachment = _renderPassDescriptor.depthAttachment;
            depthAttachment.texture = _depthTex;
            depthAttachment.loadAction = MTLLoadActionClear;
            depthAttachment.storeAction = MTLStoreActionDontCare;
            depthAttachment.clearDepth = 1.0;
        }
    } // depth
    
    if (_stencilPixelFormat != MTLPixelFormatInvalid)
    {
        BOOL doUpdate = (_stencilTex.width != texture.width) || (_stencilTex.height != texture.height) || (_stencilTex.sampleCount != _sampleCount);
        
        if (!_stencilTex || doUpdate)
        {
            //  If we need a stencil texture and don't have one, or if the depth texture we have is the wrong size
            //  Then allocate one of the proper size
            MTLTextureDescriptor *stencilTexDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: _stencilPixelFormat
                                                                                                      width: texture.width
                                                                                                     height: texture.height
                                                                                                  mipmapped: NO];
            
            stencilTexDesc.textureType = (_sampleCount > 1) ? MTLTextureType2DMultisample : MTLTextureType2D;
            stencilTexDesc.sampleCount = _sampleCount;
            
            _stencilTex = [_device newTextureWithDescriptor:stencilTexDesc];
            
            MTLRenderPassStencilAttachmentDescriptor *stencilAttachment = _renderPassDescriptor.stencilAttachment;
            stencilAttachment.texture = _stencilTex;
            stencilAttachment.loadAction = MTLLoadActionClear;
            stencilAttachment.storeAction = MTLStoreActionDontCare;
            stencilAttachment.clearStencil = 0;
        }
    } //stencil
}

- (void)setColorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    _metalLayer.pixelFormat = colorPixelFormat;
}

- (MTLPixelFormat)colorPixelFormat
{
    return _metalLayer.pixelFormat;
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
