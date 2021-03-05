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

struct VertexInput
{
    packed_float3 position;
    packed_float4 color;
};

struct VertexOutput
{
    float4 position [[ position ]];
    half4 color;
};

vertex VertexOutput vertex_program(device VertexInput *vertex_array [[ buffer(0) ]],
                                   constant Uniforms& uniforms [[ buffer(1) ]],
                                   unsigned int vid [[ vertex_id ]])
{
    VertexOutput v_out;
    
    float4 in_position = float4(float3(vertex_array[vid].position), 1.0f);
    float4x4 mv_Matrix = uniforms.modelMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;
    
    v_out.position = proj_Matrix * mv_Matrix * in_position;
    
    float4 in_color = float4(vertex_array[vid].color);
    v_out.color = half4(in_color);
    
    return v_out;
}

fragment half4 fragment_program(VertexOutput v_in [[ stage_in ]])
{
    return v_in.color;
}
