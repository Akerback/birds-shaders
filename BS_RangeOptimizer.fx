#include "ReShade.fxh"

namespace BirdsRangeOptimizerNamespace {
    uniform bool VisualizeDetectedRange <
        ui_type = "checkbox";
    > = false;

    texture TEX_Smaller {
        Width = 1024;
        Height = 1024;
        Format = R8;
    };

    texture TEX_RangeInterm {
        Width = 32;
        Height = 32;
        Format = RG8;
    };

    //Contains the true range, red channel is minimum, green channel is maximum
    texture TEX_Range {
        Width = 1;
        Height = 1;
        Format = RG8;
    };

    sampler Smaller { Texture = TEX_Smaller; };
    sampler RangeInterm { Texture = TEX_RangeInterm; };
    sampler Range { Texture = TEX_Range; };

    storage2D ST_RangeInterm { Texture = TEX_RangeInterm; };
    storage2D ST_Range { Texture = TEX_Range; };

    groupshared int minimum;
    groupshared int maximum;
    void CS_FindRange(uint3 id : SV_DispatchThreadID, uint3 tid : SV_GroupThreadID) 
    {
        int index = tid.y * 32 + tid.x;

        if (index == 0) 
        {
            minimum = 255;
            maximum = 0;
        }

        barrier();

        int luma = tex2Dfetch(Smaller, id.xy).r * 255;
        atomicMin(minimum, luma);
        atomicMax(maximum, luma);

        barrier();
        memoryBarrier();

        if (index == 0) 
        {
            int2 groupPixel = id.xy / 32;
            tex2Dstore(ST_RangeInterm, groupPixel, float4((float)minimum / 255f, (float)maximum / 255f, 0f, 1f));
        }
    }
    
    
    void CS_FindRange2(uint3 id : SV_DispatchThreadID, uint3 tid : SV_GroupThreadID) 
    {
        int index = tid.y * 32 + tid.x;

        if (index == 0) 
        {
            minimum = 255;
            maximum = 0;
        }

        barrier();

        int2 range = tex2Dfetch(RangeInterm, id.xy).rg * 255;
        atomicMin(minimum, range.x);
        atomicMax(maximum, range.y);

        barrier();
        memoryBarrier();

        if (index == 0) 
        {
            int2 groupPixel = id.xy / 32;
            tex2Dstore(ST_Range, groupPixel, float4((float)minimum / 255f, (float)maximum / 255f, 0f, 1f));
        }
    }

    float PS_Shrink(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float3 color = tex2D(ReShade::BackBuffer, uv).rgb;
        return dot(color, float3(0.299f, 0.587f, 0.114f));
    }

    float4 PS_Present(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float4 color = tex2D(ReShade::BackBuffer, uv);
        float2 minmax = tex2Dfetch(Range, (int2)0).rg;

        //Debug view
        if (VisualizeDetectedRange) {
            if ((uv.x >= 0.01f) && (uv.x <= 0.11f)) 
            {
                uv.y = 1f - uv.y;
                uint2 pixel = uv * BUFFER_SCREEN_SIZE;

                //Semi transparent bar
                if ((pixel.x + pixel.y) % 2) 
                {
                    if ((uv.y >= minmax.x) && (uv.y <= minmax.y)) return (float4)1f - color;
                }
            }
        }

        float range = minmax.y - minmax.x;
        if (range <= 0) discard;
        color /= range;
        color -= minmax.x;

        return color;
    }

    technique BirdsRangeOptimizer <ui_tooltip = "Automatically scales brightness so the image occupies the entire 0-255 color range.";> {
        /*
        How to find min and max:
        1. Shrink buffer to a workable 1024x1024
        2. Use the power of compute shaders to compute the min and max per 32x32 work group and output to a 32x32 texture
        3. Apply the same method to previous step's output to get the true min and max
        */
        pass main {
            VertexShader = PostProcessVS;
            PixelShader = PS_Shrink;
            RenderTarget = TEX_Smaller;
        }

        pass compute1 {
            //1024x1024 -> 32x32
            ComputeShader = CS_FindRange<32, 32>;
            DispatchSizeX = 32;
            DispatchSizeY = 32;
        }

        pass compute2 {
            //32x32 -> 1x1
            ComputeShader = CS_FindRange2<32, 32>;
            DispatchSizeX = 1;
            DispatchSizeY = 1;
        }

        pass present {
            VertexShader = PostProcessVS;
            PixelShader = PS_Present;
        }
    }
}