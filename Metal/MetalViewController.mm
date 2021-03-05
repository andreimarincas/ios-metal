//
//  MetalViewController.mm
//  Metal
//
//  Created by Andrei Marincas on 3/1/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import <ModelIO/ModelIO.h>
#import <MetalKit/MetalKit.h>

#import "MetalViewController.h"
#import "MetalView.h"
#import "Vertex.h"
#import "Transforms.h"
#import "SharedTypes.h"
#import "Quaternion.h"

using namespace simd;
using namespace MTL;

static const float kFOVY = 65.0f;
static const float kNear = 0.1f;
static const float kFar  = 100.0f;

static const NSUInteger kInFlightCommandBuffers = 3;

static const float kWidth  = 0.5f;
static const float kHeight = 0.5f;
static const float kDepth  = 0.5f;

static const Vertex A = { -kWidth,  kHeight,  kDepth, 1.0, 0.0, 0.0, 1.0 };
static const Vertex B = { -kWidth, -kHeight,  kDepth, 0.0, 1.0, 0.0, 1.0 };
static const Vertex C = {  kWidth, -kHeight,  kDepth, 0.0, 0.0, 1.0, 1.0 };
static const Vertex D = {  kWidth,  kHeight,  kDepth, 0.1, 0.6, 0.4, 1.0 };

static const Vertex E = { -kWidth,  kHeight, -kDepth, 1.0, 0.0, 0.0, 1.0 };
static const Vertex F = {  kWidth,  kHeight, -kDepth, 0.0, 1.0, 0.0, 1.0 };
static const Vertex G = { -kWidth, -kHeight, -kDepth, 0.0, 0.0, 1.0, 1.0 };
static const Vertex H = {  kWidth, -kHeight, -kDepth, 0.1, 0.6, 0.4, 1.0 };

static const Vertex kVertices[] = { A, B, C, D, E, F, G, H };

static const Vertex kCubeVertexData[] =
{
    A,B,C, A,C,D,   // Front
    F,H,G, E,F,G,   // Back
    
    E,G,B, E,B,A,   // Left
    D,C,H, D,H,F,   // Right
    
    E,A,D, E,D,F,   // Top
    B,G,H, B,H,C    // Bottom
};

static const float3 xAxis = { 1.0f, 0.0f, 0.0f };
static const float3 yAxis = { 0.0f, 1.0f, 0.0f };
static const float3 zAxis = { 0.0f, 0.0f, 1.0f };

@interface MetalViewController () <MetalViewControllerDelegate>

@end

@implementation MetalViewController
{
    // Using ivars instead of properties to avoid any performance penalities with the Objective-C runtime.
    
    __weak MetalView *_metalView;
    
    CADisplayLink *_displayLink;
    
    // Boolean to determine if the first draw has occured
    BOOL _firstDrawOccurred;
    
    // Time when last drawing occurred. Helps to keep track of the time interval between draws.
    CFTimeInterval _renderTime;
    
    BOOL _renderLoopPaused;
    
    id <MetalViewControllerDelegate> _delegate;
    
    // The MTLDevice provides a direct way to communicate with the GPU driver and hardware
    id <MTLDevice> _device;
    
    // Through MTLLibrary you can access any of the precompiled shaders included in your project
    id <MTLLibrary> _library;
    
    // MTLRenderPipelineState represents a compiled render pipeline that can be set on a MTLRenderCommandEncoder
    id <MTLRenderPipelineState> _pipelineState;
    
    id <MTLDepthStencilState> _depthState;
    
    MTLVertexDescriptor *_vertexDescriptor;
    
    // The MTLCommandQueue provides a way to submit commands or instructions to the GPU. Think of this as an ordered list of commands that you tell the GPU to execute, one at a time.
    id <MTLCommandQueue> _commandQueue;
    
    float4x4 _projectionMatrix;
    float4x4 _viewMatrix;
    
    dispatch_semaphore_t _inflight_semaphore;
    
    // This value will cycle from 0 to kInFlightCommandBuffers whenever a display completes ensuring renderer clients
    // can synchronize between kInFlightCommandBuffers count buffers, and thus avoiding a constant buffer from being overwritten between draws.
    uint8_t _uniformBufferIndex;
    
    id <MTLBuffer> _dynamicUniformBuffer[kInFlightCommandBuffers];
    
    MTKMesh *_mesh;
    
    float3 _position;
    float3 _scale;
    quat _orientation;
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

// Called when loaded from storyboard
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self)
    {
        [self commonInit];
    }
    
    return self;
}

// Called when loaded from nib
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self)
    {
        [self commonInit];
    }
    
    return self;
}

- (void)commonInit
{
    _projectionMatrix = identity4x4; // projection matrix will be defined in metalView:drawableSizeWillChange:
    _viewMatrix = translation(0, 0, 5); // move the scene back a little so that we can see the rotating cube
    
    _position = float3(0.0f);   // origin (no translation)
    _scale = float3(1.0f);      // no scale
    _orientation = quat_unit;   // initial orientation is the unit quaternion (no rotation)
    
    _uniformBufferIndex = 0;
    _inflight_semaphore = dispatch_semaphore_create(kInFlightCommandBuffers);
    
    _delegate = self;
    
    // Register notifications to start/stop drawing as this app moves into the background
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    [notificationCenter addObserver: self
                           selector: @selector(didEnterBackground:)
                               name: UIApplicationDidEnterBackgroundNotification
                             object: nil];
    
    [notificationCenter addObserver: self
                           selector: @selector(willEnterForeground:)
                               name: UIApplicationWillEnterForegroundNotification
                             object: nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopRenderLoop];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupMetal];
    [self configureView];
    [self preparePipelineState];
    [self createUniformBuffers];
    [self loadAssets];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Start the render loop
    [self dispatchRenderLoop];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Stop the render loop
    [self stopRenderLoop];
}

#pragma mark - Setup

- (void)setupMetal
{
    // Set the view to use the default device.
    _device = MTLCreateSystemDefaultDevice();
    
    // Create a new command queue
    _commandQueue = [_device newCommandQueue];
    
    // Load all the shader files with a metal file extension in the project.
    _library = [_device newDefaultLibrary];
    
    if (!_library)
    {
        NSLog(@"ERROR: Couldn't create a default shader library");
        
        // Assert here because if the shader libary isn't loading, nothing good will happen
        assert(0);
    }
}

- (void)configureView
{
    _metalView = (MetalView *)self.view;
    _metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    _metalView.delegate = self;
    _metalView.device = _device;
    
    // Setup view with drawable formats
    _metalView.depthPixelFormat = MTLPixelFormatDepth32Float;
    _metalView.stencilPixelFormat = MTLPixelFormatInvalid;
    _metalView.sampleCount = 4; // 1 (no sampling), 2, 4
    
    assert([_device supportsTextureSampleCount:_metalView.sampleCount]);
}

- (void)preparePipelineState
{
    // Read shader programs from the default library
    id <MTLFunction> vertexProgram = [_library newFunctionWithName:@"vertex_program"];
    
    if (!vertexProgram)
    {
        NSLog(@"ERROR: Couldn't load vertex function from default library");
    }
    
    id <MTLFunction> fragmentProgram = [_library newFunctionWithName:@"fragment_program"];
    
    if (!fragmentProgram)
    {
        NSLog(@"ERROR: Couldn't load fragment function from default library");
    }
    
    // Create a vertex descriptor for our Metal pipeline.
    // Specifies the layout of vertices the pipeline should expect.
    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    // Position
    vertexDescriptor.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[VertexAttributePosition].offset = 0;
    vertexDescriptor.attributes[VertexAttributePosition].bufferIndex = VertexBufferIndex;
    // Color
    vertexDescriptor.attributes[VertexAttributeColor].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[VertexAttributeColor].offset = 12;
    vertexDescriptor.attributes[VertexAttributeColor].bufferIndex = VertexBufferIndex;
    // Single interleaved buffer
    vertexDescriptor.layouts[VertexBufferIndex].stride = sizeof(Vertex);
    vertexDescriptor.layouts[VertexBufferIndex].stepRate = 1;
    vertexDescriptor.layouts[VertexBufferIndex].stepFunction = MTLVertexStepFunctionPerVertex;
    
    _vertexDescriptor = vertexDescriptor;
    
    // Create a pipeline state descriptor which can be used to create a compiled pipeline state object
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.sampleCount = _metalView.sampleCount;
    // Set shaders
    pipelineStateDescriptor.vertexFunction = vertexProgram;
    pipelineStateDescriptor.fragmentFunction = fragmentProgram;
    // Set vertex descriptor
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor;
    // Set framebuffer pixel format
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = _metalView.colorPixelFormat; // This is the output buffer you are rendering to – the CAMetalLayer itself.
    pipelineStateDescriptor.depthAttachmentPixelFormat = _metalView.depthPixelFormat;
    pipelineStateDescriptor.stencilAttachmentPixelFormat = _metalView.stencilPixelFormat;
    
    // Compile the pipeline configuration into a pipeline state which will be deployed to the device
    // Shader functions (from the render pipeline descriptor) are compiled when this is created unless they are obtained from the device's cache
    NSError *pipelineError = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&pipelineError];
    
    if (!_pipelineState)
    {
        NSLog(@"ERROR: Failed aquiring pipeline state: %@", pipelineError);
        
        // Cannot render anything without a valid compiled pipeline state object.
        assert(0);
    }
    
    MTLDepthStencilDescriptor *depthStencilDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStencilDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStencilDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStencilDesc];
}

- (void)createUniformBuffers
{
    // Allocate a number of uniform buffers in memory that matches the sempahore count so that
    // we always have one self contained memory buffer for each buffered frame.
    // In this case triple buffering is the optimal way to go so we cycle through 3 memory buffers.
    for (int i = 0; i < kInFlightCommandBuffers; i++)
    {
        _dynamicUniformBuffer[i] = [_device newBufferWithLength:sizeof(Uniforms) options:0];
    }
}

- (void)updateUniformBuffers
{
    id <MTLBuffer> uniformBuffer = _dynamicUniformBuffer[_uniformBufferIndex];
    
    Uniforms& uniformData = *(Uniforms *)[uniformBuffer contents];
    float4x4 modelMatrix = [self modelMatrix];
    uniformData.modelview_projection_matrix = _projectionMatrix * _viewMatrix * modelMatrix;
}

// Load all rendering assets before starting the rendering loop
- (void)loadAssets
{
    MTKMeshBufferAllocator *bufferAllocator = [[MTKMeshBufferAllocator alloc] initWithDevice:_device];
    
    NSUInteger vertexCount = sizeof(kVertices) / sizeof(Vertex);
    id <MDLMeshBuffer> vertexBuffer = [bufferAllocator newBuffer:vertexCount * sizeof(Vertex) type:MDLMeshBufferTypeVertex];
    
    for (NSUInteger i = 0; i < vertexCount; i++)
    {
        NSData *vertexData = [NSData dataWithBytes:&kVertices[i] length:sizeof(Vertex)];
        [vertexBuffer fillData:vertexData offset:i * sizeof(Vertex)];
    }
    
    NSUInteger indexCount = sizeof(kCubeVertexData) / sizeof(Vertex);
    id <MDLMeshBuffer> indexBuffer = [bufferAllocator newBuffer:indexCount * sizeof(int) type:MDLMeshBufferTypeIndex];
    NSUInteger offset = 0;
    
    for (int i = 0; i < indexCount; i++)
    {
        BOOL found = NO;
        
        for (int j = 0; j < vertexCount; j++)
        {
            if (kCubeVertexData[i] == kVertices[j])
            {
                NSData *indexData = [NSData dataWithBytes:&j length:sizeof(int)];
                [indexBuffer fillData:indexData offset:offset];
                offset += sizeof(int);
                found = YES;
                break;
            }
        }
        
        assert(found);
    }
    
    MDLSubmesh *submesh = [[MDLSubmesh alloc] initWithIndexBuffer: indexBuffer
                                                       indexCount: indexCount
                                                        indexType: MDLIndexBitDepthUInt32
                                                     geometryType: MDLGeometryTypeTriangles
                                                         material: nil];
    
    MDLVertexDescriptor *vertexDescriptor = MTKModelIOVertexDescriptorFromMetal(_vertexDescriptor);
    vertexDescriptor.attributes[VertexAttributePosition].name = MDLVertexAttributePosition;
    vertexDescriptor.attributes[VertexAttributeColor].name = MDLVertexAttributeColor;
    
    MDLMesh *mesh = [[MDLMesh alloc] initWithVertexBuffer: vertexBuffer
                                              vertexCount: vertexCount
                                               descriptor: vertexDescriptor
                                                submeshes: @[ submesh ]];
    
    NSError *error = nil;
    _mesh = [[MTKMesh alloc] initWithMesh:mesh device:_device error:&error];
    
    if (error)
    {
        NSLog(@"%@ %@", error, [error userInfo]);
        assert(0);
    }
}

#pragma mark - Rendering Loop

- (void)dispatchRenderLoop
{
    // Set up the render loop to redraw in sync with the main screen refresh rate
    
    // Create a render loop timer using a display link
    _displayLink = [[UIScreen mainScreen] displayLinkWithTarget:self selector:@selector(renderLoop)];
    _displayLink.frameInterval = 1; // display link will fire for every display frame
    
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)stopRenderLoop
{
    if (_displayLink)
    {
        [_displayLink invalidate];
        _displayLink = nil;
    }
}

- (void)renderLoop
{
    // Display (render)
    
    if (!_firstDrawOccurred)
    {
        _timeSinceLastDraw = 0.0;
        _renderTime = CACurrentMediaTime();
        _firstDrawOccurred = YES;
    }
    else
    {
        CFTimeInterval currentTime = CACurrentMediaTime();
        _timeSinceLastDraw = currentTime - _renderTime;
        _renderTime = currentTime;
    }
    
    // Update renderering state before drawing
    [_delegate update:self];
    
    // Call the display method directly on the render view
    [_metalView display];
}

- (BOOL)isPaused
{
    return _renderLoopPaused;
}

- (void)setPaused:(BOOL)paused
{
    if (paused != _renderLoopPaused)
    {
        if (_displayLink)
        {
            // Inform the rendering delegate we are about to pause/resume
            [_delegate viewController:self willPause:paused];
            
            _displayLink.paused = paused;
        }
        
        _renderLoopPaused = paused;
    }
}

#pragma mark - App States

- (void)didEnterBackground:(NSNotification *)notification
{
    [self setPaused:YES];
}

- (void)willEnterForeground:(NSNotification *)notification
{
    [self setPaused:NO];
}

#pragma mark - MetalViewDelegate (Render)

- (void)metalView:(MetalView *)view drawableSizeWillChange:(CGSize)size
{
    // When this is called, update the view and projection matrices since this means the view orientation or size has changed.
    
    float aspect = fabs(view.bounds.size.width / view.bounds.size.height);
    _projectionMatrix = perspective_fov(kFOVY, aspect, kNear, kFar);
}

- (void)drawInMetalView:(MetalView *)view
{
    // This semaphore will get signaled once the GPU completes a frame's work via addCompletedHandler callback below,
    // signifying the CPU can go ahead and prepare another frame.
    dispatch_semaphore_wait(_inflight_semaphore, DISPATCH_TIME_FOREVER);
    
    // Prior to sending any data to the GPU, constant buffers should be updated accordingly on the CPU.
    [self updateUniformBuffers];
    
    // Create a new command buffer for each renderpass to the current drawable.
    // This is a serial list of commands for the device to execute.
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    // Create a Render Pass Descriptor object to store the framebuffer and texture information
    MTLRenderPassDescriptor *renderPassDescriptor = view.renderPassDescriptor; // based on the current drawable
    
    if (renderPassDescriptor)
    {
        // Start a Render command
        
        // Create first a render command encoder so we can render into something.
        // The render command encoder is a container for graphics rendering state and the code to translate the state into a command format that the device can execute.
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor]; // Returns a render command endcoder to encode into this command buffer
        
        [renderEncoder setViewport:{ 0, 0, _metalView.drawableSize.width, _metalView.drawableSize.height, 0, 1 }];
        
        [renderEncoder setDepthStencilState:_depthState];
        
        // Set the pipeline state
        [renderEncoder setRenderPipelineState:_pipelineState];
        
        // Set the our per frame uniforms.
        [renderEncoder setVertexBuffer:_dynamicUniformBuffer[_uniformBufferIndex] offset:0 atIndex:UniformBufferIndex];
        
        NSUInteger bufferIndex = 0;
        
        // Set mesh's vertex buffers.
        for (MTKMeshBuffer *vertexBuffer in _mesh.vertexBuffers)
        {
            if (vertexBuffer.buffer != nil)
            {
                [renderEncoder setVertexBuffer:vertexBuffer.buffer offset:vertexBuffer.offset atIndex:bufferIndex];
            }
            
            bufferIndex++;
        }
        
        // Render each submesh.
        for (MTKSubmesh *submesh in _mesh.submeshes)
        {
            [renderEncoder drawIndexedPrimitives:submesh.primitiveType indexCount:submesh.indexCount indexType:submesh.indexType indexBuffer:submesh.indexBuffer.buffer indexBufferOffset:submesh.indexBuffer.offset];
        }
        
        // Declare that all command generation from this encoder is complete, and detach from the MTLCommandBuffer.
        [renderEncoder endEncoding];
        
        // Tell CoreAnimation when to present this drawable.
        // The new texture is presented as soon as the drawing completes.
        [commandBuffer presentDrawable:view.currentDrawable]; // schedule a present once rendering to the framebuffer is complete
    }
    
    // Call the view's completion handler which is required by the view since it will signal its semaphore and set up the next buffer
    __block dispatch_semaphore_t inflight_semaphore = _inflight_semaphore;
    
    [commandBuffer addCompletedHandler:^(id <MTLCommandBuffer> buffer) {
        
        // GPU has completed rendering the frame and is done using the contents of any buffers previously encoded on the CPU for that frame.
        // Signal the semaphore and allow the CPU to proceed and construct the next frame.
        dispatch_semaphore_signal(inflight_semaphore);
    }];
    
    // Commit the transaction to send the task to the GPU. The commit method puts the command buffer into the queue.
    [commandBuffer commit]; // Finalize rendering here. This will push the command buffer to the GPU.
    
    // This index represents the current portion of the ring buffer being used for a given frame's uniforms buffer updates.
    // Once the CPU has completed updating a shared CPU/GPU memory buffer region for a frame, this index should be updated so the
    // next portion of the ring buffer can be written by the CPU. Note, this should only be done *after* all writes to any
    // buffers requiring synchronization for a given frame is done in order to avoid writing a region of the ring buffer that the GPU may be reading.
    _uniformBufferIndex = (_uniformBufferIndex + 1) % kInFlightCommandBuffers;
}

#pragma mark - MetalViewControllerDelegate (Update)

- (void)update:(MetalViewController *)controller
{
    // Use this to update app globals
    
    NSTimeInterval t = controller.timeSinceLastDraw;
    
    // Speed in degrees/second
    static const float speedX = 360.0f / 12.0f;
    static const float speedY = 360.0f / 8.0f;
    static const float speedZ = 360.0f / 6.0f;
    
    [self rotateBy:t * speedZ aroundAxis:zAxis];
    [self rotateBy:t * speedY aroundAxis:yAxis];
    [self rotateBy:t * speedX aroundAxis:xAxis];
}

- (void)viewController:(MetalViewController *)controller willPause:(BOOL)pause
{
    // Timer is suspended/resumed
    // Can do any non-rendering related background work here when suspended
}

#pragma mark - Model

- (float4x4)modelMatrix
{
    float4x4 pos_Matrix = translation(_position);
    float4x4 rot_Matrix = rotation_mat(_orientation);
    float4x4 scale_Matrix = scale(_scale);
    
    return pos_Matrix * rot_Matrix * scale_Matrix;
}

- (void)rotateBy:(float)angle aroundAxis:(const float3&)axis
{
    _orientation = normalize(rotation_quat(angle, axis) * _orientation);
    
//    NSString *q_str = [NSString stringWithCString:string(_orientation).c_str() encoding:[NSString defaultCStringEncoding]];
//    NSLog(@"q = %@ , |q| = %f , |q|^2 = %f", q_str, norm(_orientation), norm_squared(_orientation));
}

@end
