#include "ReShade.fxh"

namespace BirdsVideoCompressionNamespace {
    //--Settings
    uniform float CompressionRatio <
        ui_type = "drag";
        ui_min = 0f;
        ui_max = 1f;
    > = 0.1f;

    //--Textures, samples, etc.
    texture TEX_CompressedOut 
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
    };

    texture TEX_Interm < pooled = true; >
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
    };

    sampler CompressedOut { Texture = TEX_CompressedOut; };
    sampler Interm { Texture = TEX_Interm; };

    float4 PS_gather(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float4 color = tex2D(ReShade::BackBuffer, uv);
        float4 storedColor = tex2D(CompressedOut, uv);

        if (length(color - storedColor) < CompressionRatio) discard;

        return color;
    }
    
    //One shader to show and copy
    float4 PS_main(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float4 color = tex2D(Interm, uv);

        return color;
    }

    technique BirdsVideoCompression {
        pass gather 
        {
            VertexShader = PostProcessVS;
            PixelShader = PS_gather;
            RenderTarget = TEX_Interm;
        }

        pass present 
        {
            VertexShader = PostProcessVS;
            PixelShader = PS_main;
        }

        //Have to copy since reading and writing to the same texture in a pixelshader doesn't work
        pass copy 
        {
            VertexShader = PostProcessVS;
            PixelShader = PS_main;
            RenderTarget = TEX_CompressedOut;
        }
    }
}