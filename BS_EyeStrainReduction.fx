#include "ReShade.fxh"

namespace BirdsSmartLevelsNamespace {
    #ifndef BIRDSEYESTRAIN_MODE
        #define BIRDSEYESTRAIN_MODE 0
    #endif

    uniform float Strength <
        ui_type = "drag";
    > = 1.0f;

#if (BIRDSEYESTRAIN_MODE != 0)
    uniform float Threshold <
        ui_type = "drag";
    > = 0.9f;
#endif

    float3 sinusoidalScale(float3 i) {
        const float pi = 3.14159265359f;

        i = sin((i - 0.5f) * pi) * 0.5f + 0.5f;

        return i;
    }

#if (BIRDSEYESTRAIN_MODE == 0)
    float4 PS_sinusoidalMode(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float4 color = tex2D(ReShade::BackBuffer, uv);

        float3 sinusoidalColor = sinusoidalScale(color.rgb) * (1 - Strength * 0.1f);
        color.r = lerp(color.r, sinusoidalColor.r, color.r * color.r);
        color.g = lerp(color.g, sinusoidalColor.g, color.g * color.g);
        color.b = lerp(color.b, sinusoidalColor.b, color.b * color.b);

        return color;
    }
#else
    float4 PS_thresholdMode(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float4 color = tex2D(ReShade::BackBuffer, uv);

        float3 tempColor = min(color.rgb, float3(Threshold, Threshold, Threshold));
        float3 adjustment = max(color - Threshold, float3(0f, 0f, 0f)) * (1f - Strength * 0.5f);

        return float4(tempColor + adjustment, 1f);
    }
#endif

    technique BirdsEyeStrainReduction {
        pass main {
            VertexShader = PostProcessVS;
        #if (BIRDSEYESTRAIN_MODE == 0)
            PixelShader = PS_sinusoidalMode;
        #else
            PixelShader = PS_thresholdMode;
        #endif
        }
    }
}