#include "ReShade.fxh"

namespace BirdsTelevisionNamespace 
{
    texture TEX_btv_pal < pooled = true; > 
    {
        Width = 720;
        Height = 625;
    };

    texture TEX_btv_ntsc < pooled = true; > 
    {
        Width = 720;
        Height = 525;
    };

    sampler btv_pal { Texture = TEX_btv_pal; SRGBTexture = false; };
    sampler btv_ntsc { Texture = TEX_btv_ntsc; SRGBTexture = false; };

    uniform uint bbw_resolutionMode <
        ui_label = "Resolution Mode";
        ui_type = "combo";
        ui_items = "PAL (625p)\0NTSC (525p)\0Native\0";
    > = 0;

    uniform float bbw_saturation <
        ui_label = "Saturation";
        ui_type = "drag";
        ui_min = 0f;
        ui_max = 5f;
    > = 1f;

    float rec601ig(float channel) 
    {
        if (channel < 0.018f) return 4.5f * channel;
        else return 1.099f * pow(channel, 0.45f) - 0.099f;
    }

    float3 rec601invGamma(float3 color) 
    {
        color.r = rec601ig(color.r);
        color.g = rec601ig(color.g);
        color.b = rec601ig(color.b);

        return color;
    }

    float4 bbw_copy(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  
    {
        float4 color = tex2D(ReShade::BackBuffer, uv);
        color.rgb = pow(color.rgb, 2.2f);
        color.rgb = rec601invGamma(color.rgb);

        return color;
    }

    float4 bbw_present(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET 
    {
        float4 lumaSample = float4(0f, 0f, 0f, 1f);
        float4 chromaSample = float4(0f, 0f, 0f, 1f);
        
        switch (bbw_resolutionMode)
        {
            case 0: //PAL
                lumaSample = tex2D(btv_pal, uv);
                chromaSample = tex2D(btv_pal, float2(floor(uv.x * 360.0f) / 360.0f, uv.y));
                break;
            case 1: //NTSC
                lumaSample = tex2D(btv_ntsc, uv);
                chromaSample = tex2D(btv_ntsc, float2(floor(uv.x * 360.0f) / 360.0f, uv.y));
                break;
            case 2: //Monitor native
                lumaSample = tex2D(ReShade::BackBuffer, uv);

                //Convert on the spot
                lumaSample.rgb = pow(lumaSample.rgb, 2.2f);
                lumaSample.rgb = rec601invGamma(lumaSample.rgb);

                chromaSample = tex2D(ReShade::BackBuffer, float2(floor(uv.x * (BUFFER_WIDTH / 2f)) / (BUFFER_WIDTH / 2f), uv.y));

                //Convert on the spot
                chromaSample.rgb = pow(chromaSample.rgb, 2.2f);
                chromaSample.rgb = rec601invGamma(chromaSample.rgb);
                break;
            default:
                break;
        }

        //Convert to YPbPr so chroma can be subsampled accurately
        float Y = 0.299f * lumaSample.r + 0.587f * lumaSample.g + 0.114f * lumaSample.b;
        float Pb = -0.168736f * chromaSample.r - 0.331264f * chromaSample.g + 0.5f * chromaSample.b;
        float Pr = 0.5f * chromaSample.r - 0.418688f * chromaSample.g - 0.081312f * chromaSample.b;

        //Modify values before the next step
        Y += 16f / 256f;
        Pb = Pb * bbw_saturation + 0.5f;
        Pr = Pr * bbw_saturation + 0.5f;

        //Map YPbPr back to RGB
        float3 color;
        color.r = 1.164f * Y + 1.596f * Pr - 0.871f;
        color.g = 1.164f * Y - 0.392f * Pb - 0.813f * Pr + 0.53f;
        color.b = 1.164f * Y + 2.017f * Pb - 1.081f;

        return float4(color, 1f);
    }

    technique BirdsTelevision < ui_tooltip = "Maps colors and performs chroma subsampling according to the Rec.601 SDTV standard."; > 
    {
        pass palcopy 
        {
            VertexShader = PostProcessVS;
            PixelShader = bbw_copy;
            RenderTarget = TEX_btv_pal;
        }

        pass ntsccopy 
        {
            VertexShader = PostProcessVS;
            PixelShader = bbw_copy;
            RenderTarget = TEX_btv_ntsc;
        }

        pass present 
        {
            VertexShader = PostProcessVS;
            PixelShader = bbw_present;
        }
    }
}