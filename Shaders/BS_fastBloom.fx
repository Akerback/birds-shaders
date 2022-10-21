#include "ReShade.fxh"

namespace BirdsFastBloomNamespace {
    #ifndef FASTBLOOM_SHOW_BLOOMTEXTURE
        #define FASTBLOOM_SHOW_BLOOMTEXTURE 0
    #endif

    #ifndef FASTBLOOM_TONEMAP
        #define FASTBLOOM_TONEMAP 1
    #endif

    //--Settings
    uniform float Intensity <
        ui_type = "drag";
        ui_tooltip = "Bloom Intensity. High values will cause aliasing.";
        ui_step = 0.01f;
        ui_min = 0.0f;
    > = 1.0f;

    uniform float Threshold <
        ui_type = "drag";
        ui_tooltip = "Controls how a bright a pixel must be contribute to bloom.";
        ui_min = 1f;
        ui_max = 10f;
        ui_step = 0.01f;
    > = 5f;

    uniform uint Size <
        ui_type = "slider";
        ui_tooltip = "How far bloom spreads. Has a direct effect on performance.";
        ui_min = 1;
        ui_max = 9;
    > = 6;

#if FASTBLOOM_TONEMAP
    uniform uint Mapping <
        ui_category = "Tonemapping";
        ui_type = "combo";
        ui_items = "Uncharted 2\0Reinhard\0ACES\0";
    > = 2;

    uniform float ExposureBias <
        ui_type = "drag";
        ui_tooltip = "In F-stops. Each increase of one doubles the brightness.";
        ui_step = 0.01f;
    > = 0f;
#endif

    //--Textures
    texture TEX_Bloom <pooled = false;> {
        Width = 512;
        Height = 512;
        MipLevels = 10;
        Format = RGBA8;
    };
    sampler Bloom { Texture = TEX_Bloom; };

    //--Functions
#if FASTBLOOM_TONEMAP
    float3 Uncharted2Tonemap(float3 x)
    {
        const float A = 0.15;
        const float B = 0.50;
        const float C = 0.10;
        const float D = 0.20;
        const float E = 0.02;
        const float F = 0.30;

        float3 mappedColor = ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;

        return mappedColor;
    }

    float3 ReinhardTonemap(float3 x) 
    {
        return x / (x + 1f);
    }

    float3 ACESTonemap(float3 x) 
    {
        const float A = 2.51f;
        const float B = 0.03f;
        const float C = 2.43f;
        const float D = 0.59f;
        const float E = 0.14f;
        
        return (x * (A * x + B)) / (x * (C * x + D) + E);
    }

    //Auto pick tonemap based on setting
    float3 Map(float3 col) 
    {
        float Exposure = pow(2f, ExposureBias);

        switch (Mapping) 
        {
            case 0:
                return Uncharted2Tonemap(pow(col, 1f / 2.2f) * Exposure) / Uncharted2Tonemap(pow(Exposure, 1f / 2.2f));
            case 1:
                //+2.27 f-stops looks best
                return ReinhardTonemap(col * Exposure * pow(2, 2.27f));
            case 2:
                //+0.7 f-stops looks best
                return ACESTonemap(col * Exposure * pow(2, 0.7f));
            default:
                return 0f;
        }
    }
#endif

    //--Pixel Shaders
    float4 PS_Gather(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float4 color = tex2D(ReShade::BackBuffer, uv);
        return pow(color, Threshold);
    }

    float4 PS_Apply(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float4 color = tex2D(ReShade::BackBuffer, uv);
        
        //Only blur here is the bilinear interpolation from mipmapping
        float4 bloomColor = tex2Dlod(Bloom, float4(uv, 0, 0));
        for (int i = 1; i < Size; i++) 
        {
            bloomColor += tex2Dlod(Bloom, float4(uv, 0, i));
        }
        bloomColor *= Intensity / (Size + 1);

    #if FASTBLOOM_SHOW_BLOOMTEXTURE
        return bloomColor;
    #else
        #if FASTBLOOM_TONEMAP
            //Apply some tonemapping to make it pretty
            color.rgb = Map(color.rgb + bloomColor.rgb);
            return float4(pow(color.rgb, 2.2f), 1f);
        #else
            return color + bloomColor;
        #endif
    #endif
    }

    technique BirdsFastBloom <ui_tooltip = "Very fast bloom with optional tonemapping. Doesn't play well with high intensities.";> {
        pass gather {
            VertexShader = PostProcessVS;
            PixelShader = PS_Gather;
            RenderTarget = TEX_Bloom;
        }

        pass apply {
            VertexShader = PostProcessVS;
            PixelShader = PS_Apply;
        }
    }
}