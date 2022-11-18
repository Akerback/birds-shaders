#include "ReShade.fxh"

namespace BirdsGradientGeneratorNamespace {
    uniform float3 ColorsMultiplierX <
        ui_type = "drag";
    > = float3(1f, 0f, 0f);

    uniform float3 ColorsMultiplierY <
        ui_type = "drag";
    > = float3(0f, 1f, 0f);

    float4 PS_main(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float3 color = ColorsMultiplierX * uv.x + ColorsMultiplierY * uv.y;

        return float4(color, 1f);
    }

    technique BirdsGradientGenerator {
        pass main {
            VertexShader = PostProcessVS;
            PixelShader = PS_main;
        }
    }
}