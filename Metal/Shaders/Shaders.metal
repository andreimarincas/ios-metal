//
//  Shaders.metal
//  Metal
//
//  Created by Andrei Marincas on 2/24/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "SharedTypes.h"

using namespace metal;
using namespace MTL;

struct VertexInput {
    float3 position [[ attribute(VertexAttributePosition) ]];
    float4 color    [[ attribute(VertexAttributeColor) ]];
};

struct VertexOutput {
    float4 position [[ position ]];
    half4 color;
};

vertex VertexOutput vertex_program(VertexInput v_in [[ stage_in ]],
                                   constant Uniforms& uniforms [[ buffer(UniformBufferIndex) ]])
{
    VertexOutput v_out;
    
    float4 in_position = float4(float3(v_in.position), 1.0f);
    float4x4 mv_proj_Matrix = uniforms.modelview_projection_matrix;
    
    v_out.position = mv_proj_Matrix * in_position;
    
    float4 in_color = float4(v_in.color);
    v_out.color = half4(in_color);
    
    return v_out;
}

fragment half4 fragment_program(VertexOutput v_out [[ stage_in ]])
{
    return v_out.color;
}
