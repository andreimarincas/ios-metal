//
//  SharedTypes.h
//  Metal
//
//  Created by Andrei Marincas on 3/15/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#ifndef SharedTypes_h
#define SharedTypes_h

#import <simd/simd.h>

#ifdef __cplusplus

namespace MTL
{
    struct Uniforms
    {
        simd::float4x4 modelMatrix;
        simd::float4x4 projectionMatrix;
    };
}

#endif

#endif /* SharedTypes_h */
