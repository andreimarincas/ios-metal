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

extern const float kPi_f;
extern const float k1Div180_f;
extern const float k1Div360_f;
extern const float kRadians;

namespace MTL
{
    static const simd::float4x4 identity4x4 = matrix_identity_float4x4;
    
    float radians(const float& degrees);
    
    simd::float4x4 scale(const float& sx,
                         const float& sy,
                         const float& sz);
    
    simd::float4x4 scale(const simd::float3& s);
    
    simd::float4x4 translation(const float& x,
                               const float& y,
                               const float& z);
    
    simd::float4x4 translation(const simd::float3& t);
    
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
    
    simd::float4x4 ortho2d_oc(const float& left,
                              const float& right,
                              const float& bottom,
                              const float& top,
                              const float& near,
                              const float& far);
    
    simd::float4x4 ortho2d_oc(const simd::float3& origin,
                              const simd::float3& size);
    
    simd::float4x4 frustum_oc(const float& left,
                              const float& right,
                              const float& bottom,
                              const float& top,
                              const float& near,
                              const float& far);
    
    simd::float4x4 perspective_fov(const float& fovy,
                                   const float& aspect,
                                   const float& near,
                                   const float& far);
}

#endif

#endif /* Transforms_h */
