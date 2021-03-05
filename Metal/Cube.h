//
//  Cube.h
//  Metal
//
//  Created by Andrei Marincas on 3/28/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import "Node.h"

@interface Cube : Node

- (instancetype)initWithName:(NSString *)name
                      device:(id <MTLDevice>)device;

@end
