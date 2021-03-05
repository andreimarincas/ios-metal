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
    // Indices of vertex attribute in descriptor.
    enum VertexAttributes {
        VertexAttributePosition = 0,
        VertexAttributeColor    = 1
    };
    
    // Indices for buffer bind points
    enum BufferIndex {
        VertexBufferIndex  = 0,
        UniformBufferIndex = 1
    };
    
    struct Uniforms {
        // Frame uniforms
        simd::float4x4 modelview_projection_matrix;
        //simd::float4x4 normal_matrix;
        
        // Material uniforms
        
        
    } __attribute__ ((aligned (256)));
}

#endif

#endif /* SharedTypes_h */
