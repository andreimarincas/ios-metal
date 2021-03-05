//
//  Scene.h
//  Metal
//
//  Created by Andrei Marincas on 4/8/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import "Node.h"

@interface Scene : Node

- (instancetype)initWithName:(NSString *)name
                      device:(id <MTLDevice>)device;

- (void)updateUniformBuffer:(NSUInteger)bufferIndex
           projectionMatrix:(const simd::float4x4&)projMatrix;

@end
