//
//  Transforms.mm
//  Metal
//
//  Created by Andrei Marincas on 3/15/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import "Transforms.h"

const float kPi_f      = float(M_PI);
const float k1Div180_f = 1.0f / 180.0f;
const float k1Div360_f = 1.0f / 360.0f;
const float kRadians   = k1Div180_f * kPi_f;

float MTL::radians(const float& degrees)
{
    return kRadians * degrees;
}

simd::float4x4 MTL::scale(const float& sx,
                          const float& sy,
                          const float& sz)
{
    simd::float4 v = { sx, sy, sz, 1.0f };
    
    return simd::float4x4(v);
}

simd::float4x4 MTL::scale(const simd::float3& s)
{
    simd::float4 v = { s.x, s.y, s.z, 1.0f };
    
    return simd::float4x4(v);
}

simd::float4x4 MTL::translation(const simd::float3& t)
{
    simd::float4x4 M = matrix_identity_float4x4;
    
    M.columns[3].xyz = t;
    
    return M;
}

simd::float4x4 MTL::translation(const float& x,
                                const float& y,
                                const float& z)
{
    return MTL::translation((simd::float3){ x, y, z });
}

simd::float4x4 MTL::rotation(const float& angle,
                             const simd::float3& r)
{
    float a = angle * k1Div180_f;
    float s = 0.0f;
    float c = 0.0f;
    
    // Computes the sine and cosine of pi times angle (measured in radians)
    // faster and gives exact results for angle = 90, 180, 270, etc.
    __sincospif(a, &s, &c);
    
    float k = 1.0f - c;
    
    simd::float3 u = simd::normalize(r);
    simd::float3 v = s * u;
    simd::float3 w = k * u;
    
    simd::float4 P;
    simd::float4 Q;
    simd::float4 R;
    simd::float4 S;
    
    P.x = w.x * u.x + c;
    P.y = w.x * u.y + v.z;
    P.z = w.x * u.z - v.y;
    P.w = 0.0f;
    
    Q.x = w.x * u.y - v.z;
    Q.y = w.y * u.y + c;
    Q.z = w.y * u.z + v.x;
    Q.w = 0.0f;
    
    R.x = w.x * u.z + v.y;
    R.y = w.y * u.z - v.x;
    R.z = w.z * u.z + c;
    R.w = 0.0f;
    
    S.x = 0.0f;
    S.y = 0.0f;
    S.z = 0.0f;
    S.w = 1.0f;
    
    return simd::float4x4(P, Q, R, S);
}

simd::float4x4 MTL::rotation(const float& angle,
                             const float& x,
                             const float& y,
                             const float& z)
{
    simd::float3 r = { x, y, z };
    
    return MTL::rotation(angle, r);
}

simd::float4x4 MTL::ortho2d(const float& left,
                            const float& right,
                            const float& bottom,
                            const float& top,
                            const float& near,
                            const float& far)
{
    float sLength = 1.0f / (right - left);
    float sHeight = 1.0f / (top   - bottom);
    float sDepth  = 1.0f / (far   - near);
    
    simd::float4 P;
    simd::float4 Q;
    simd::float4 R;
    simd::float4 S;
    
    P.x = 2.0f * sLength;
    P.y = 0.0f;
    P.z = 0.0f;
    P.w = 0.0f;
    
    Q.x = 0.0f;
    Q.y = 2.0f * sHeight;
    Q.z = 0.0f;
    Q.w = 0.0f;
    
    R.x = 0.0f;
    R.y = 0.0f;
    R.z = sDepth;
    R.w = 0.0f;
    
    S.x =  0.0f;
    S.y =  0.0f;
    S.z = -near * sDepth;
    S.w =  1.0f;
    
    return simd::float4x4(P, Q, R, S);
}

simd::float4x4 MTL::ortho2d(const simd::float3& origin,
                            const simd::float3& size)
{
//    return MTL::ortho2d(origin.x, origin.y, origin.z, size.x, size.y, size.z);
    return MTL::ortho2d(origin.x, size.x, origin.y, size.y, origin.z, size.z);
}

simd::float4x4 MTL::ortho2d_oc(const float& left,
                               const float& right,
                               const float& bottom,
                               const float& top,
                               const float& near,
                               const float& far)
{
    float sLength = 1.0f / (right - left);
    float sHeight = 1.0f / (top   - bottom);
    float sDepth  = 1.0f / (far   - near);
    
    simd::float4 P;
    simd::float4 Q;
    simd::float4 R;
    simd::float4 S;
    
    P.x = 2.0f * sLength;
    P.y = 0.0f;
    P.z = 0.0f;
    P.w = 0.0f;
    
    Q.x = 0.0f;
    Q.y = 2.0f * sHeight;
    Q.z = 0.0f;
    Q.w = 0.0f;
    
    R.x = 0.0f;
    R.y = 0.0f;
    R.z = sDepth;
    R.w = 0.0f;
    
    S.x = -sLength * (left + right);
    S.y = -sHeight * (top + bottom);
    S.z = -sDepth  * near;
    S.w =  1.0f;
    
    return simd::float4x4(P, Q, R, S);
}

simd::float4x4 MTL::ortho2d_oc(const simd::float3& origin,
                               const simd::float3& size)
{
    return MTL::ortho2d_oc(origin.x, origin.y, origin.z, size.x, size.y, size.z);
}

simd::float4x4 MTL::frustum_oc(const float& left,
                               const float& right,
                               const float& bottom,
                               const float& top,
                               const float& near,
                               const float& far)
{
    float sWidth  = 1.0f / (right - left);
    float sHeight = 1.0f / (top   - bottom);
    float sDepth  = far  / (far   - near);
    float dNear   = 2.0f * near;
    
    simd::float4 P;
    simd::float4 Q;
    simd::float4 R;
    simd::float4 S;
    
    P.x = dNear * sWidth;
    P.y = 0.0f;
    P.z = 0.0f;
    P.w = 0.0f;
    
    Q.x = 0.0f;
    Q.y = dNear * sHeight;
    Q.z = 0.0f;
    Q.w = 0.0f;
    
    R.x = -sWidth  * (right + left);
    R.y = -sHeight * (top   + bottom);
    R.z =  sDepth;
    R.w =  1.0f;
    
    S.x =  0.0f;
    S.y =  0.0f;
    S.z = -sDepth * near;
    S.w =  0.0f;
    
    return simd::float4x4(P, Q, R, S);
}

simd::float4x4 MTL::perspective_fov(const float& fovy,
                                    const float& aspect,
                                    const float& near,
                                    const float& far)
{
    float angle  = MTL::radians(0.5f * fovy);
    float yScale = 1.0f/ std::tan(angle);
    float xScale = yScale / aspect;
    float zScale = far / (far - near);
    
    simd::float4 P;
    simd::float4 Q;
    simd::float4 R;
    simd::float4 S;
    
    P.x = xScale;
    P.y = 0.0f;
    P.z = 0.0f;
    P.w = 0.0f;
    
    Q.x = 0.0f;
    Q.y = yScale;
    Q.z = 0.0f;
    Q.w = 0.0f;
    
    R.x = 0.0f;
    R.y = 0.0f;
    R.z = zScale;
    R.w = 1.0f;
    
    S.x =  0.0f;
    S.y =  0.0f;
    S.z = -near * zScale;
    S.w =  0.0f;
    
    return simd::float4x4(P, Q, R, S);
}
