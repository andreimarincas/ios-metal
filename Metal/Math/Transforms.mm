//
//  Transforms.mm
//  Metal01
//
//  Created by Andrei Marincas on 3/15/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

//#import <cmath>
//#import <iostream>

#import "Transforms.h"

simd::float4x4 MTL::identity()
{
    simd::float4 v = { 1.0f, 1.0f, 1.0f, 1.0f };
    
    return simd::float4x4(v);
}

simd::float4x4 MTL::scale(const float& x,
                          const float& y,
                          const float& z)
{
    simd::float4 v = { x, y, z, 1.0f };
    
    return simd::float4x4(v);
}

simd::float4x4 MTL::scale(const simd::float3& s)
{
    simd::float4 v = { s.x, s.y, s.z, 1.0f };
    
    return simd::float4x4(v);
}
