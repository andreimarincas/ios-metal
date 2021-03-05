//
//  Shaders.metal
//  MetalDemo
//
//  Created by Andrei Marincas on 2/24/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "SharedTypes.h"

using namespace metal;
using namespace MTL;

struct PackedVertex
{
    packed_float3 position;
    float4 color;
};

struct ShaderVertex
{
    float4 position [[ position ]];
    half4 color;
};

vertex ShaderVertex vertex_program(device PackedVertex *vertex_array [[ buffer(0) ]],
                                   constant TransformData& transform_data [[ buffer(1) ]],
                                   unsigned int vid [[ vertex_id ]])
{
    ShaderVertex v_out;
    
    float4 in_position = float4(float3(vertex_array[vid].position), 1.0);
    v_out.position = transform_data.transform * in_position;
    
    half4 in_color = half4(vertex_array[vid].color);
    v_out.color = in_color;
    
    return v_out;
}

fragment half4 fragment_program(ShaderVertex v_in [[ stage_in ]])
{
    return v_in.color;
}
