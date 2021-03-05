//
//  Scene.mm
//  Metal
//
//  Created by Andrei Marincas on 4/8/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import "Scene.h"
#import "Transforms.h"

using namespace simd;
using namespace MTL;

@interface Scene ()
{
    float4x4 _viewMatrix;
}

@end

@implementation Scene

- (instancetype)initWithName:(NSString *)name
                      device:(id <MTLDevice>)device
{
    self = [super initWithName:name vertices:nil device:device];
    
    if (self)
    {
        _viewMatrix = translation(0, 0, 5);
    }
    
    return self;
}

- (void)updateUniformBuffer:(NSUInteger)bufferIndex
           projectionMatrix:(const simd::float4x4&)projMatrix
{
    [self updateUniformBuffer:bufferIndex
            parentModelMatrix:identity4x4()
         viewProjectionMatrix:projMatrix * _viewMatrix];
    
//    [self updateUniformBuffer:bufferIndex
//         viewProjectionMatrix:projMatrix * _viewMatrix];
//    
//    for (Node *node in [self children])
//    {
//        [node updateUniformBuffer:bufferIndex];
//    }
}

@end
