//
//  MetalRenderer.mm
//  Metal
//
//  Created by Andrei Marincas on 3/1/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import "MetalRenderer.h"
#import "Transforms.h"
#import "SharedTypes.h"

using namespace simd;
using namespace MTL;

static const float kFOVY   = 65.0f;
static const float kNear   = 0.1f;
static const float kFar    = 100.0f;

static const float kWidth  = 0.5f;
static const float kHeight = 0.5f;
static const float kDepth  = 0.5f;

struct Vertex
{
    float x, y, z;
    float r, g, b, a;
};

static const Vertex A = { -kWidth,  kHeight,  kDepth, 1.0, 0.0, 0.0, 1.0 };
static const Vertex B = { -kWidth, -kHeight,  kDepth, 0.0, 1.0, 0.0, 1.0 };
static const Vertex C = {  kWidth, -kHeight,  kDepth, 0.0, 0.0, 1.0, 1.0 };
static const Vertex D = {  kWidth,  kHeight,  kDepth, 0.1, 0.6, 0.4, 1.0 };

static const Vertex E = { -kWidth,  kHeight, -kDepth, 1.0, 0.0, 0.0, 1.0 };
static const Vertex F = {  kWidth,  kHeight, -kDepth, 0.0, 1.0, 0.0, 1.0 };
static const Vertex G = { -kWidth, -kHeight, -kDepth, 0.0, 0.0, 1.0, 1.0 };
static const Vertex H = {  kWidth, -kHeight, -kDepth, 0.1, 0.6, 0.4, 1.0 };

static const Vertex kCubeVertexData[] =
{
    A,B,C, A,C,D,   // Front
    F,H,G, E,F,G,   // Back
    
    E,G,B, E,B,A,   // Left
    D,C,H, D,H,F,   // Right
    
    E,A,D, E,D,F,   // Top
    B,G,H, B,H,C    // Bottom
};

static const long kInFlightCommandBuffers = 3;

@interface MetalRenderer ()
{
    // The MTLDevice provides a direct way to communicate with the GPU driver and hardware
    id <MTLDevice>              _device;
    
    // The MTLBuffer is a typeless allocation accessible by both the CPU and the GPU (MTLDevice)
    id <MTLBuffer>              _vertexBuffer;
    
    // Through MTLLibrary you can access any of the precompiled shaders included in your project
    id <MTLLibrary>             _library;
    
    // MTLRenderPipelineState represents a compiled render pipeline that can be set on a MTLRenderCommandEncoder
    id <MTLRenderPipelineState> _pipelineState;
    
    // The MTLCommandQueue provides a way to submit commands or instructions to the GPU. Think of this as an ordered list of commands that you tell the GPU to execute, one at a time.
    id <MTLCommandQueue>        _commandQueue;
    
    // Globals used in update calculation
    float4x4                    _projectionMatrix;
    float                       _rotation;
    
    dispatch_semaphore_t        _inflight_semaphore;
    id <MTLBuffer>              _dynamicUniformsBuffer[kInFlightCommandBuffers];
    
    // This value will cycle from 0 to kInFlightCommandBuffers-1 whenever a display completes ensuring renderer clients
    // can synchronize between kInFlightCommandBuffers count buffers, and thus avoiding a constant buffer from being overwritten between draws.
    NSUInteger                  _uniformsBufferIndex;
}

@end

@implementation MetalRenderer

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _projectionMatrix = identity();
        _inflight_semaphore = dispatch_semaphore_create(kInFlightCommandBuffers);
    }
    
    return self;
}

- (void)configure:(MetalView *)view
{
    // Get the view's device
    _device = view.device;
    
    // Create a new command queue
    _commandQueue = [_device newCommandQueue];
    
    // Create a new default library
    _library = [_device newDefaultLibrary];
    
    if (!_library)
    {
        NSLog(@"ERROR: Couldn't create a default shader library");
        
        // Assert here because if the shader libary isn't loading, nothing good will happen
        assert(0);
    }
    
    // Prepare pipeline
    [self preparePipelineState];
    
    // Allocate buffers before rendering
    [self createBuffers];
    
    // Set ourself as delegate to handle rendering in metal view
    view.delegate = self;
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
    
    // Create a pipeline state descriptor which can be used to create a compiled pipeline state object
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    
    // Set shaders
    pipelineStateDescriptor.vertexFunction = vertexProgram;
    pipelineStateDescriptor.fragmentFunction = fragmentProgram;
    
    // Set framebuffer pixel format
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm; // This is the output buffer you are rendering to – the CAMetalLayer itself.
    
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
}

- (void)createBuffers
{
    _vertexBuffer = [_device newBufferWithBytes: kCubeVertexData
                                         length: sizeof(kCubeVertexData)
                                        options: MTLResourceOptionCPUCacheModeDefault];
    
    // Allocate a number of buffers in memory that matches the sempahore count so that
    // we always have one self contained memory buffer for each buffered frame.
    // In this case triple buffering is the optimal way to go so we cycle through 3 memory buffers.
    for (int i = 0; i < kInFlightCommandBuffers; i++)
    {
        _dynamicUniformsBuffer[i] = [_device newBufferWithLength:sizeof(Uniforms) options:0];
        
        // Write initial uniforms values
        Uniforms& uniformsData = *(Uniforms *)[_dynamicUniformsBuffer[i] contents];
        uniformsData.modelMatrix = identity();
        uniformsData.projectionMatrix = identity();
    }
}

- (void)updateUniformsBuffer
{
    float4x4 baseModelMatrix = translation(0, 0, 3) * rotation(_rotation, 1, 1, 1);
    
    Uniforms& uniformsData = *(Uniforms *)[_dynamicUniformsBuffer[_uniformsBufferIndex] contents];
    uniformsData.modelMatrix = baseModelMatrix;
    uniformsData.projectionMatrix = _projectionMatrix;
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
    [self updateUniformsBuffer];
    
    // Create a new command buffer for each renderpass to the current drawable.
    // This ia a serial list of commands for the device to execute.
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    // Create a Render Pass Descriptor object to store the framebuffer and texture information
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor; // based on the current drawable
    
    if (renderPassDescriptor)
    {
        // Start a Render command
        
        // Create first a render command encoder so we can render into something.
        // The render command encoder is a container for graphics rendering state and the code to translate the state into a command format that the device can execute.
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor]; // Returns a render command endcoder to encode into this command buffer
        
        // Use backface culling to fix trasparency
        [renderEncoder setCullMode:MTLCullModeFront];
        [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        
        // Set the pipeline state
        [renderEncoder setRenderPipelineState:_pipelineState];
        
        // Set buffers
        [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
        [renderEncoder setVertexBuffer:_dynamicUniformsBuffer[_uniformsBufferIndex] offset:0 atIndex:1];
        
        // Tell the GPU to draw a set of triangles based on the vertex buffer.
        // Each triangle consists of 3 vertices, starting at index 0 inside the vertex buffer.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:36];
        
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
    _uniformsBufferIndex = (_uniformsBufferIndex + 1) % kInFlightCommandBuffers;
}

#pragma mark - MetalViewControllerDelegate (Update)

- (void)update:(MetalViewController *)controller
{
    // Use this to update app globals
    
    _rotation += controller.timeSinceLastDraw * 30.0f;
}

- (void)viewController:(MetalViewController *)controller willPause:(BOOL)pause
{
    // Timer is suspended/resumed
    // Can do any non-rendering related background work here when suspended
}

@end
