//
//  Transforms.h
//  Metal
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
    
    simd::float4x4 scale(const float& sx,
                         const float& sy,
                         const float& sz);
    
    simd::float4x4 scale(const simd::float3& s);
    
    simd::float4x4 rotation(const float& angle,
                            const float& x,
                            const float& y,
                            const float& z);
    
    simd::float4x4 rotation(const float& angle,
                            const simd::float3& r);
    
    simd::float4x4 ortho2d(const float& left,
                           const float& right,
                           const float& bottom,
                           const float& top,
                           const float& near,
                           const float& far);
    
    simd::float4x4 ortho2d(const simd::float3& origin,
                           const simd::float3& size);
}

#endif

#endif /* Transforms_h */
