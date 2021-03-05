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

static const float kEquiH_f     = sqrtf(3.0f) / 2.0f; // height of an equilateral triangle with side = 1 (aprox. 0.866)
static const float kOneThird_f  = kEquiH_f / 3.0f;
static const float kTwoThirds_f = 2.0f * kOneThird_f;

// position, color
static const float vertex_data[] =
{
     0.0f,  kTwoThirds_f, 0.0f,    1.0f, 0.0f, 0.0f, 1.0f,
    -0.5f, -kOneThird_f,  0.0f,    0.0f, 1.0f, 0.0f, 1.0f,
     0.5f, -kOneThird_f,  0.0f,    0.0f, 0.0f, 1.0f, 1.0f
};

@interface MetalRenderer ()
{
    // The MTLDevice provides a direct way to communicate with the GPU driver and hardware
    id <MTLDevice>              _device;
    
    // The MTLBuffer is a typeless allocation accessible by both the CPU and the GPU (MTLDevice)
    id <MTLBuffer>              _vertexBuffer;
    id <MTLBuffer>              _transformBuffer;
    
    // Through MTLLibrary you can access any of the precompiled shaders included in your project
    id <MTLLibrary>             _library;
    
    // MTLRenderPipelineState represents a compiled render pipeline that can be set on a MTLRenderCommandEncoder
    id <MTLRenderPipelineState> _pipelineState;
    
    // The MTLCommandQueue provides a way to submit commands or instructions to the GPU. Think of this as an ordered list of commands that you tell the GPU to execute, one at a time.
    id <MTLCommandQueue>        _commandQueue;
    
    // Globals used in update calculation
    float4x4                    _modelViewMatrix;
    float4x4                    _projectionMatrix;
    float                       _rotation;
}

@end

@implementation MetalRenderer

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _modelViewMatrix = identity();
        _projectionMatrix = identity();
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
    _vertexBuffer = [_device newBufferWithBytes: vertex_data
                                         length: sizeof(vertex_data)
                                        options: MTLResourceOptionCPUCacheModeDefault];
    
    _transformBuffer = [_device newBufferWithLength:sizeof(TransformData) options:0];
    
    // Write initial data to transform buffer
    TransformData *data = (TransformData *)[_transformBuffer contents];
    float4x4 t = identity();
    data->transform = t;
}

- (void)updateTransformBuffer
{
    TransformData *data = (TransformData *)[_transformBuffer contents];
    float4x4 baseModelMatrix = rotation(_rotation, 0, 0, 1);
    float4x4 t = _projectionMatrix * _modelViewMatrix * baseModelMatrix;
    data->transform = t;
}

#pragma mark - MetalViewDelegate (Render)

- (void)metalView:(MetalView *)view drawableSizeWillChange:(CGSize)size
{
    // When this is called, update the view and projection matrices since this means the view orientation or size has changed.
    
    float w = view.bounds.size.width;
    float h = view.bounds.size.height;
    float scale_xy  = fminf(w, h) / 2.0f;
    
    _modelViewMatrix = scale(scale_xy, scale_xy, 1);
    _projectionMatrix = ortho2d(0, w, 0, h, 0, 1);
}

- (void)drawInMetalView:(MetalView *)view
{
    // Prior to sending any data to the GPU, constant buffers should be updated accordingly on the CPU.
    [self updateTransformBuffer];
    
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
        
        // Set the pipeline state
        [renderEncoder setRenderPipelineState:_pipelineState];
        
        // Set buffers
        [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
        [renderEncoder setVertexBuffer:_transformBuffer offset:0 atIndex:1];
        
        // Tell the GPU to draw a set of triangles based on the vertex buffer.
        // Each triangle consists of 3 vertices, starting at index 0 inside the vertex buffer, and there is 1 triangle total.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3 instanceCount:1];
        
        // Declare that all command generation from this encoder is complete, and detach from the MTLCommandBuffer.
        [renderEncoder endEncoding];
        
        // Tell CoreAnimation when to present this drawable.
        // The new texture is presented as soon as the drawing completes.
        [commandBuffer presentDrawable:view.currentDrawable]; // schedule a present once rendering to the framebuffer is complete
    }
    
    // Commit the transaction to send the task to the GPU. The commit method puts the command buffer into the queue.
    [commandBuffer commit]; // Finalize rendering here. This will push the command buffer to the GPU.
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
