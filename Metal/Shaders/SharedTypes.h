//
//  SharedTypes.h
//  Metal01
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
    struct TransformData
    {
        simd::float4x4 transform;
    };
}

#endif

#endif /* SharedTypes_h */
