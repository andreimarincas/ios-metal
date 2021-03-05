//
//  Node.mm
//  Metal
//
//  Created by Andrei Marincas on 3/25/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import "Node.h"
#import "Transforms.h"
#import "SharedTypes.h"
#import "MetalRenderer.h"
#import "Quaternion.h"

using namespace simd;
using namespace MTL;

@implementation NSValue (Vertex)

+ (NSValue *)valueWithVertex:(Vertex)vertex
{
    return [NSValue valueWithBytes:&vertex objCType:@encode(Vertex)];
}

- (Vertex)vertexValue
{
    Vertex vertex;
    [self getValue:&vertex];
    return vertex;
}

@end

@interface Node ()
{
    id <MTLBuffer> _dynamicUniformBuffer[kInFlightCommandBuffers];
    
    NSMutableArray<Node *> *_children;
    
    quat _orientation;
}

@end

@implementation Node

- (instancetype)initWithName:(NSString *)name
                    vertices:(NSArray<NSValue *> *)vertices
                      device:(id <MTLDevice>)device
{
    self = [super init];
    
    if (self)
    {
        self.name = name;
        
        // Create the vertex buffer
        if ([vertices count])
        {
            size_t sizeOfVertex = sizeof(Vertex);
            NSMutableData *vertexData = [[NSMutableData alloc] initWithCapacity:[vertices count] * sizeOfVertex];
            
            for (NSInteger i = 0; i < [vertices count]; i++)
            {
                Vertex vertex = [vertices[i] vertexValue];
                [vertexData appendBytes:&vertex length:sizeOfVertex];
            }
            
            _vertexBuffer = [device newBufferWithBytes: [vertexData bytes]
                                                length: [vertexData length]
                                               options: MTLResourceOptionCPUCacheModeDefault];
            _vertexCount = [vertices count];
        }
        
        // Allocate a number of uniform buffers in memory that matches the sempahore count so that
        // we always have one self contained memory buffer for each buffered frame.
        // In this case triple buffering is the optimal way to go so we cycle through 3 memory buffers.
        for (int i = 0; i < kInFlightCommandBuffers; i++)
        {
            _dynamicUniformBuffer[i] = [device newBufferWithLength:sizeof(Uniforms) options:0];
        }
        
        // Initial model transformation values
        _scale = float3(1.0f); // no scale
        _orientation = quat_identity; // initial orientation is the unit quaternion (no rotation).
        
        _children = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)rotateBy:(float)angle aroundAxis:(const float3&)axis
{
    _orientation = normalize(rotation_quat(angle, axis) * _orientation);
    
//    NSString *q_str = [NSString stringWithCString:string(_orientation).c_str() encoding:[NSString defaultCStringEncoding]];
//    NSLog(@"q = %@ , |q| = %f , |q|^2 = %f", q_str, norm(_orientation), norm_squared(_orientation));
}

- (id <MTLBuffer>)currentUniformBuffer
{
    return _dynamicUniformBuffer[_uniformBufferIndex];
}

- (float4x4)modelMatrix
{
    float4x4 pos_Matrix = translation(_position);
    float4x4 scale_Matrix = scale(_scale);
    float4x4 rot_Matrix = rotation_mat(_orientation);
    
    return pos_Matrix * rot_Matrix * scale_Matrix;
}

- (void)updateUniformBuffer:(NSUInteger)bufferIndex
       viewProjectionMatrix:(const simd::float4x4&)viewProjMatrix
{
    _uniformBufferIndex = bufferIndex;
    id <MTLBuffer> uniformBuffer = [self currentUniformBuffer];
    
    Uniforms& uniformData = *(Uniforms *)[uniformBuffer contents];
    uniformData.modelview_projection_matrix = viewProjMatrix * [self modelMatrix];
}

- (void)updateUniformBuffer:(NSUInteger)bufferIndex
          parentModelMatrix:(const simd::float4x4&)pModelMatrix
       viewProjectionMatrix:(const simd::float4x4&)viewProjMatrix
{
    _uniformBufferIndex = bufferIndex;
    id <MTLBuffer> uniformBuffer = [self currentUniformBuffer];
    
    float4x4 modelMatrix = pModelMatrix * [self modelMatrix];
    
    Uniforms& uniformData = *(Uniforms *)[uniformBuffer contents];
    uniformData.modelview_projection_matrix = viewProjMatrix * modelMatrix;
    
    for (Node *node in _children)
    {
        [node updateUniformBuffer:bufferIndex
                parentModelMatrix:modelMatrix
             viewProjectionMatrix:viewProjMatrix];
    }
}

//- (void)updateUniformBuffer:(NSUInteger)bufferIndex
//{
//    _uniformBufferIndex = bufferIndex;
//    
//    id <MTLBuffer> uniformBuffer = [self currentUniformBuffer];
//    id <MTLBuffer> pUniformBuffer = [_parent currentUniformBuffer];
//    
//    Uniforms& uniformData = *(Uniforms *)[uniformBuffer contents];
//    Uniforms& pUniformData = *(Uniforms *)[pUniformBuffer contents];
//    
//    uniformData.modelview_projection_matrix = pUniformData.modelview_projection_matrix * [self modelMatrix];
//    
//    for (Node *node in _children)
//    {
//        [node updateUniformBuffer:bufferIndex];
//    }
//}

- (void)render:(id <MTLRenderCommandEncoder>)encoder
{
    for (Node *node in _children)
    {
        [node render:encoder];
    }
    
    if (!_hidden && _vertexCount)
    {
        // Use backface culling to fix trasparency
        [encoder setCullMode:MTLCullModeFront];
        [encoder setFrontFacingWinding:MTLWindingCounterClockwise];
        
        // Set buffers
        [encoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
        [encoder setVertexBuffer:[self currentUniformBuffer] offset:0 atIndex:1];
        
        // Tell the GPU to draw a set of triangles based on the vertex buffer.
        // Each triangle consists of 3 vertices, starting at index 0 inside the vertex buffer.
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:_vertexCount];
    }
}

- (NSArray<Node *> *)children
{
    return _children;
}

- (void)addChild:(Node *)child
{
    [child removeFromParentNode];
    [_children addObject:child];
    child.parent = self;
}

- (void)removeFromParentNode
{
    if (_parent)
    {
        [(NSMutableArray *)[_parent children] removeObject:self];
    }
}

@end
