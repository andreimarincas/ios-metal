//
//  Vertex.mm
//  Metal
//
//  Created by Andrei Marincas on 4/20/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import "Vertex.h"

bool Vertex::operator==(const Vertex& v) const
{
    if (x == v.x && y == v.y && z == v.z &&
        r == v.r && g == v.g && b == v.b && a == v.a)
    {
        return true;
    }
    
    return false;
}

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
