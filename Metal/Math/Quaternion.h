//
//  Quaternion.h
//  Metal
//
//  Created by Andrei Marincas on 4/5/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#ifndef Quaternion_h
#define Quaternion_h

#import <simd/simd.h>
#import <string>

#ifdef __cplusplus

namespace MTL
{
    // q = w + xi + yj + zk
    struct Quaternion
    {
        float x;
        float y;
        float z;
        float w; // scalar
        
        Quaternion();
        Quaternion(float x, float y, float z, float w);
        Quaternion(const Quaternion& q);
        Quaternion& operator=(const Quaternion& q);
        ~Quaternion();
        
        inline void operator*=(const Quaternion& q);
    };
    typedef Quaternion quat;
    
    static const quat quat_identity = { 0.0f, 0.0f, 0.0f, 1.0f }; // Unit quaternion 1 + 0i + 0j + 0k with real part 1 and imaginary part 0.
    
    // Norm
    float norm(const quat& q);
    float norm_squared(const quat& q);
    
    quat normalize(const quat& q);
    
    // Product
    quat product(const quat& p, const quat& q); // Returns the Hamilton product p * q.
    
    inline void Quaternion::operator*=(const Quaternion& q) { *this = product(*this, q); }
    inline quat operator*(const quat& p, const quat& q) { return product(p, q); };
    
    // Multiplication by a scalar
    inline quat operator*(const quat& q, float s) { return quat(s * q.x, s * q.y, s * q.z, s * q.w); };
    inline quat operator*(float s, const quat& q) { return quat(s * q.x, s * q.y, s * q.z, s * q.w); };
    
    // Rotation
    quat rotation_quat(float angle, const simd::float3& axis); // Returns the quaternion (a, v) = (cos(angle/2), axis * sin(angle/2)). The angle parameter must be in degrees, the angle used will be converted into radians. The axis used will be normalized.
    simd::float4x4 rotation_mat(const quat& q); // Returns the rotation matrix representation of a quaternion.
    
    // String representation
    std::string string(const quat& q);
}

#endif

#endif /* Quaternion_h */
