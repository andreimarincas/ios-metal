//
//  Cube.mm
//  Metal
//
//  Created by Andrei Marincas on 3/28/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import "Cube.h"

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

static const Vertex kCubeVertexData[] =
{
    A,B,C, A,C,D,   // Front
    F,H,G, E,F,G,   // Back
    
    E,G,B, E,B,A,   // Left
    D,C,H, D,H,F,   // Right
    
    E,A,D, E,D,F,   // Top
    B,G,H, B,H,C    // Bottom
};

static NSArray<NSValue *>* CubeVertices()
{
    size_t vertexCount = sizeof(kCubeVertexData) / sizeof(Vertex);
    NSMutableArray<NSValue *> *cubeVertices = [NSMutableArray arrayWithCapacity:vertexCount];
    
    for (int i = 0; i < vertexCount; i++)
    {
        const Vertex& vertex = kCubeVertexData[i];
        [cubeVertices addObject:@(vertex)];
    }
    
    return cubeVertices;
}

@implementation Cube

- (instancetype)initWithName:(NSString *)name
                      device:(id <MTLDevice>)device
{
    self = [super initWithName:name vertices:CubeVertices() device:device];
    
    if (self)
    {
        // Custom implementation
    }
    
    return self;
}

@end
