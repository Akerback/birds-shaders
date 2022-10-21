#include "ReShade.fxh"

namespace BirdsBrightnessMeasureNamespace {
    uniform float centreSlope <
        ui_type = "drag";
    > = 1.0f;

    texture TEX_Gather <pooled = false;>
    {
        Width = 64;
        Height = 64;

        MipLevels = 6;
        Format = R8;
    };

    sampler Gather { Texture = TEX_Gather; };

    float4 PS_Gather(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  
    {
        float3 color = tex2D(ReShade::BackBuffer, uv);
        color.rgb = pow(color.rgb, 1f / 2.2f);
        float grayscale = dot(color, float3(0.299f, 0.587f, 0.114f));

        return float4(grayscale, 0f, 0f, 1f);
    }

    float4 PS_Show(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET 
    {
        float4 color = tex2D(ReShade::BackBuffer, uv);
        float brightness = tex2Dlod(Gather, float4(uv, 0, 5));

        if (uv.x < 0.2f) {
            if (abs(uv.y - 0.5f) < 0.005f) return float4((float3)0f, 1f);
            if (abs((1f - uv.y) - brightness) < 0.01f) return float4((float3)1f - color.rgb, 1f);
        }
        else if (uv.x < 0.2f + 0.005f) return float4((float3)0f, 1f);

        discard;
    }

    technique BirdsBrightMeasure {
        pass main {
            VertexShader = PostProcessVS;
            PixelShader = PS_Gather;
            RenderTarget = TEX_Gather;
        }

        pass display 
        {
            VertexShader = PostProcessVS;
            PixelShader = PS_Show;
        }
    }
}