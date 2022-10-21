#include "ReShade.fxh"

namespace BirdsCheckerBoardNamespace {
    float4 PS_main(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        int2 pixel = uv * BUFFER_SCREEN_SIZE;

        if ((pixel.x + pixel.y) % 2 == 0) return tex2D(ReShade::BackBuffer, uv);

        //Vertical checkerboard resolution
        float4 c1 = tex2Doffset(ReShade::BackBuffer, uv, int2(0, -1));
        float4 c2 = tex2Doffset(ReShade::BackBuffer, uv, int2(0, 1));

        float4 c3 = lerp(c1, c2, 0.5f);

        //Horisontal
        c1 = tex2Doffset(ReShade::BackBuffer, uv, int2(-1, 0));
        c2 = tex2Doffset(ReShade::BackBuffer, uv, int2(1, 0));

        float4 c4 = lerp(c1, c2, 0.5f);

        return lerp(c3, c4, 0.5f);
    }

    technique BirdsCheckerboardRender {
        pass main {
            VertexShader = PostProcessVS;
            PixelShader = PS_main;
        }
    }
}