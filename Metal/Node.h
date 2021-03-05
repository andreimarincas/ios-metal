//
//  Node.h
//  Metal
//
//  Created by Andrei Marincas on 3/25/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <simd/simd.h>

#import "Quaternion.h"

struct Vertex
{
    float x, y, z;      // position
    float r, g, b, a;   // color
} __attribute__((objc_boxable));

typedef struct Vertex Vertex;

@interface NSValue (Vertex)

+ (NSValue *)valueWithVertex:(Vertex)vertex;
- (Vertex)vertexValue;

@end

static const simd::float3 xAxis = { 1.0f, 0.0f, 0.0f };
static const simd::float3 yAxis = { 0.0f, 1.0f, 0.0f };
static const simd::float3 zAxis = { 0.0f, 0.0f, 1.0f };

@interface Node : NSObject

@property (nonatomic, copy) NSString *name;

- (instancetype)initWithName:(NSString *)name
                    vertices:(NSArray<NSValue *> *)vertices
                      device:(id <MTLDevice>)device;

@property (nonatomic, readonly) id <MTLBuffer> vertexBuffer;
@property (nonatomic, readonly) NSUInteger vertexCount;

@property (nonatomic, readonly) simd::float3& position;
@property (nonatomic, readonly) simd::float3& scale;

- (void)rotateBy:(float)angle aroundAxis:(const simd::float3&)axis;

@property (nonatomic, readonly) simd::float4x4 modelMatrix;

@property (nonatomic, assign) NSUInteger uniformBufferIndex;
- (id <MTLBuffer>)currentUniformBuffer;

- (void)updateUniformBuffer:(NSUInteger)bufferIndex
       viewProjectionMatrix:(const simd::float4x4&)viewProjMatrix;

- (void)updateUniformBuffer:(NSUInteger)bufferIndex
          parentModelMatrix:(const simd::float4x4&)pModelMatrix
       viewProjectionMatrix:(const simd::float4x4&)viewProjMatrix;

//- (void)updateUniformBuffer:(NSUInteger)bufferIndex;

- (void)render:(id <MTLRenderCommandEncoder>)encoder;

@property (nonatomic, getter=isHidden) BOOL hidden;

@property (nonatomic, readonly) NSArray<Node *> *children;
- (void)addChild:(Node *)child;

@property (nonatomic, weak) Node *parent;
- (void)removeFromParentNode;

@end
