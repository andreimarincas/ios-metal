//
//  Quaternion.mm
//  Metal
//
//  Created by Andrei Marincas on 4/5/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sstream>
#import "Quaternion.h"
#import "Transforms.h"

MTL::Quaternion::Quaternion() : x(0.0f), y(0.0f), z(0.0f), w(0.0f) {}

MTL::Quaternion::Quaternion(float x, float y, float z, float w) : x(x), y(y), z(z), w(w) {}

MTL::Quaternion::Quaternion(const Quaternion& q) : x(q.x), y(q.y), z(q.z), w(q.w) {}

MTL::Quaternion& MTL::Quaternion::operator=(const Quaternion& q)
{
    if (this != &q)
    {
        x = q.x;
        y = q.y;
        z = q.z;
        w = q.w;
    }
    
    return *this;
}

MTL::Quaternion::~Quaternion() {}

float MTL::norm(const quat& q)
{
    return sqrtf(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z);
}

float MTL::norm_squared(const quat& q)
{
    return q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z;
}

MTL::quat MTL::normalize(const quat& q)
{
    float norm = MTL::norm(q);
    
    if (norm == 0.0f || norm == 1.0f)
    {
        return q;
    }
    
    return (1.0f / norm) * q;
}

MTL::quat MTL::product(const quat& p, const quat& q)
{
    float W = p.w * q.w - p.x * q.x - p.y * q.y - p.z * q.z;
    float X = p.w * q.x + p.x * q.w + p.y * q.z - p.z * q.y;
    float Y = p.w * q.y - p.x * q.z + p.y * q.w + p.z * q.x;
    float Z = p.w * q.z + p.x * q.y - p.y * q.x + p.z * q.w;
    
    return quat(X, Y, Z, W);
}

MTL::quat MTL::rotation_quat(float angle, const simd::float3& axis)
{
    float a = angle * k1Div360_f;
    float s = 0.0f;
    float c = 0.0f;
    
    // Computes the sine and cosine of pi times angle (measured in radians)
    // faster and gives exact results for angle = 90, 180, 270, etc.
    __sincospif(a, &s, &c);
    
    simd::float3 u = simd::normalize(axis);
    simd::float3 v = s * u;
    
    return quat(v.x, v.y, v.z, c);
}

simd::float4x4 MTL::rotation_mat(const quat& q)
{
    simd::float4 P;
    simd::float4 Q;
    simd::float4 R;
    simd::float4 S;
    
    float a = q.w * q.w;
    float v1 = q.x * q.x;
    float v2 = q.y * q.y;
    float v3 = q.z * q.z;
    
    float av1 = 2 * q.w * q.x;
    float av2 = 2 * q.w * q.y;
    float av3 = 2 * q.w * q.z;
    
    float v1v2 = 2 * q.x * q.y;
    float v1v3 = 2 * q.x * q.z;
    float v2v3 = 2 * q.y * q.z;
    
    P.x = a + v1 - v2 - v3;
    P.y = v1v2 + av3;
    P.z = v1v3 - av2;
    P.w = 0.0f;
    
    Q.x = v1v2 - av3;
    Q.y = a - v1 + v2 - v3;
    Q.z = v2v3 + av1;
    Q.w = 0.0f;
    
    R.x = v1v3 + av2;
    R.y = v2v3 - av1;
    R.z = a - v1 - v2 + v3;
    R.w = 0.0f;
    
    S.x = 0.0f;
    S.y = 0.0f;
    S.z = 0.0f;
    S.w = 1.0f;
    
    return simd::float4x4(P, Q, R, S);
}

std::string MTL::string(const quat& q)
{
    std::stringstream ss;
    ss << q.w;
    ss << (q.x < 0 ? " - " : " + ") << fabsf(q.x) << "i";
    ss << (q.y < 0 ? " - " : " + ") << fabsf(q.y) << "j";
    ss << (q.z < 0 ? " - " : " + ") << fabsf(q.z) << "k";
    
    return ss.str();
}
