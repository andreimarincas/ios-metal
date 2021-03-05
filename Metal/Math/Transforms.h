//
//  Transforms.h
//  Metal01
//
//  Created by Andrei Marincas on 3/15/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#ifndef Transforms_h
#define Transforms_h

#import <simd/simd.h>

#ifdef __cplusplus

namespace MTL
{
    simd::float4x4 identity();
    
    simd::float4x4 scale(const float& x,
                         const float& y,
                         const float& z);

    simd::float4x4 scale(const simd::float3& s);
}

#endif

#endif /* Transforms_h */
