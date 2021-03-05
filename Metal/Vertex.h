//
//  Vertex.h
//  Metal
//
//  Created by Andrei Marincas on 4/20/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import <Foundation/Foundation.h>

struct Vertex
{
    float x, y, z;      // position
    float r, g, b, a;   // color
    
    bool operator==(const Vertex& v) const;
    
} __attribute__((objc_boxable));

typedef struct Vertex Vertex;

@interface NSValue (Vertex)

+ (NSValue *)valueWithVertex:(Vertex)vertex;
- (Vertex)vertexValue;

@end
