#include "ReShade.fxh"

namespace BirdsHDRNamespace {
    #ifndef BIRDHDR_BLOOM_ENABLED
        #define BIRDHDR_BLOOM_ENABLED 1
    #endif

#if BIRDHDR_BLOOM_ENABLED
    #ifndef BIRDHDR_BLOOM_SIZE
        #define BIRDHDR_BLOOM_SIZE 3
    #endif

    //Standard deviation used for gaussian blur distribution
    static const float sigma = (float)BIRDHDR_BLOOM_SIZE / 2f;

    #ifndef BIRDHDR_BLOOM_SHOW_TEX
        #define BIRDHDR_BLOOM_SHOW_TEX 0
    #endif
#endif

    #ifndef BIRDHDR_MANUAL_EXPOSURE
        #define BIRDHDR_MANUAL_EXPOSURE 0
    #endif

    //Settings
#if BIRDHDR_BLOOM_ENABLED
    uniform float intensity <
        ui_category = "Bloom";
        ui_label = "Intensity";
        ui_tooltip = "How strong the bloom effect is";
        ui_type = "drag";
        ui_step = 0.01f;
        ui_min = 0f;
    > = 1.0f;

    uniform float threshold <
        ui_category = "Bloom";
        ui_label = "Threshold";
        ui_tooltip = "How bright a pixel must be to contribute to bloom";
        ui_type = "drag";
        ui_min = 1f;
        ui_max = 10f;
        ui_step = 0.01f;
    > = 2f;

    uniform float SpreadBias <
        ui_category = "Bloom";
        ui_tooltip = "How far the bloom spreads";
        ui_type = "drag";
        ui_min = 0.01f;
        ui_step = 0.01f;
    > = 0.5f;
#endif
    uniform uint Mapping <
        ui_category = "Tonemapping";
        ui_type = "combo";
        ui_items = "None\0Uncharted 2\0Reinhard\0ACES\0";
    > = 3;

    uniform float ExposureBias <
        ui_category = "Tonemapping";
        ui_tooltip = "In F-stops. Each increase of one doubles the brightness. No performance cost.";
        ui_type = "drag";
        ui_step = 0.01f;
    > = 0.0f;

#if !BIRDHDR_MANUAL_EXPOSURE
    #ifndef BIRDHDR_SMART_ADAPTATION
        #define BIRDHDR_SMART_ADAPTATION 1
    #endif

    #if !BIRDHDR_SMART_ADAPTATION
        uniform float ExposureTarget <
            ui_category = "Tonemapping";
            ui_tooltip = "Average pixel brightness targetted by adaptation.";
            ui_type = "drag";
            ui_step = 0.001f;
            ui_min = 0f;
            ui_max = 1f;
        > = 0.35f;

        uniform float MinExposure <
            ui_category = "Tonemapping";
            ui_type = "drag";
            ui_step = 0.001f;
            ui_min = 0f;
        > = 0.75f;

        uniform float MaxExposure <
            ui_category = "Tonemapping";
            ui_type = "drag";
            ui_step = 0.001f;
            ui_min = 0f;
        > = 1.25f;
    #endif

    static const float ExposureAdaptRate = 0.05f;

    //--Textures
    #if BIRDHDR_SMART_ADAPTATION
        texture TEX_bhdr_OriginalBrightness <pooled = true;> {
            Width = 256;
            Height = 256;
            MipLevels = 8;
            Format = R8;
        };
        sampler bhdr_OriginalBrightness { Texture = TEX_bhdr_OriginalBrightness; };
    #endif

    texture TEX_bhdr_Adapt <pooled = false;> {
        Width = 256;
        Height = 256;
        MipLevels = 8;
        Format = R8;
    };

    texture TEX_bhdr_Exposure <pooled = false;> {
        Width = 1;
        Height = 1;
        Format = R16F;
    };

    texture TEX_bhdr_PrevExposure <pooled = false;> {
        Width = 1;
        Height = 1;
        Format = R16F;
    };

    sampler bhdr_PrevExposure { Texture = TEX_bhdr_PrevExposure; };
    sampler bhdr_Exposure { Texture = TEX_bhdr_Exposure; };
    sampler bhdr_Adapt { Texture = TEX_bhdr_Adapt; };
#endif

    texture TEX_bhdr_Bloom <pooled = true;> {
        Width = 1024;
        Height = 1024;
        MipLevels = 7;
        Format = RGBA8;
    };
    sampler Bloom { Texture = TEX_bhdr_Bloom; };

    //Bloom texture spam, identical sizes for use with multiple render targets
    texture TEX_B1 <pooled = true; > { Width = 256; Height = 256; };
    texture TEX_B2 <pooled = true; > { Width = 256; Height = 256; };
    texture TEX_B3 <pooled = true; > { Width = 256; Height = 256; };

    sampler B1 {Texture = TEX_B1;};
    sampler B2 {Texture = TEX_B2;};
    sampler B3 {Texture = TEX_B3;};

    //--Functions
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
    #if BIRDHDR_MANUAL_EXPOSURE
        float exposure = pow(2f, ExposureBias);
    #else
        float exposure = tex2D(bhdr_Exposure, float2(0f, 0f)).r;
        if (exposure == 0f) exposure = 1f;
    #endif
        //Reinhard and ACES have extra exposure biases
        switch (Mapping) 
        {
            case 0:
                return col * exposure;
            case 1:
                //Map exposure in gamma space as white
                return pow(Uncharted2Tonemap(pow(col, 1f / 2.2f) * exposure) / Uncharted2Tonemap(pow(exposure, 1f / 2.2f)), 2.2f);
            case 2:
                //Reinhard looks best when given linear space colors
                return pow(ReinhardTonemap(col * exposure * pow(2, 2.27f)), 2.2f);//+2.27 exposure bias
            case 3:
                //ACES works on linear space colors
                return pow(ACESTonemap(col * exposure * pow(2, 0.7f)), 2.2f);//+0.7 exposure bias
            default:
                return 0f;
        }
    }
    
#if BIRDHDR_BLOOM_ENABLED
    float NormalDist(float x, float sigma) 
    {
        static const float pi = 3.14159265359f;
        static const float rootOfTwoPi = 2.50662827463f;

        float xOverSigma = x / sigma;

        return exp(-0.5f * xOverSigma * xOverSigma) / sigma / rootOfTwoPi;
    }

    //--Pixel Shaders
    float4 PS_Gather(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float4 color = tex2D(ReShade::BackBuffer, uv);
        return pow(color, threshold);
    }
    
    void PS_MultiBlurX(float4 p : SV_POSITION, float2 uv: TEXCOORD, out float4 c1 : SV_TARGET0, out float4 c2 : SV_TARGET1, out float4 c3: SV_TARGET2) {
        static const float3x2 pSizes = float3x2(
            1f / 256f, 0f,
            1f / 64f, 0f,
            1f / 16f, 0f
        );

        //Horisontal blurs for 3 different buffers, shove 'em in a matrix
        float gVal = NormalDist(0f, sigma);
        float3x3 cmat = float3x3(
            tex2Dlod(Bloom, float4(uv, 0, 2)).rgb,
            tex2Dlod(Bloom, float4(uv, 0, 4)).rgb,
            tex2Dlod(Bloom, float4(uv, 0, 6)).rgb
        ) * gVal;

        float3x2 offsets = float3x2(0, 0, 0, 0, 0, 0);
        for (float i = 1; i <= BIRDHDR_BLOOM_SIZE; i++) {
            gVal = NormalDist(i, sigma);
            offsets += pSizes;
            
            //Samples -> matrix. Multiplication and addition might be single operations instead of 3-9 separate?
            cmat += float3x3(
                tex2Dlod(Bloom, float4(uv + offsets[0], 0, 2)).rgb + tex2Dlod(Bloom, float4(uv - offsets[0], 0, 2)).rgb,
                tex2Dlod(Bloom, float4(uv + offsets[1], 0, 4)).rgb + tex2Dlod(Bloom, float4(uv - offsets[1], 0, 4)).rgb,
                tex2Dlod(Bloom, float4(uv + offsets[2], 0, 6)).rgb + tex2Dlod(Bloom, float4(uv - offsets[2], 0, 6)).rgb
            ) * gVal;
        }

        cmat = cmat / 0.95f;//Compensation for not sampling to infinity
        c1 = float4(cmat[0], 1f);
        c2 = float4(cmat[1], 1f);
        c3 = float4(cmat[2], 1f);
    }
#endif

    float4 PS_Apply(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {

        float4 color = tex2D(ReShade::BackBuffer, uv);

    #if !BIRDHDR_BLOOM_ENABLED
        //Tonemapping only
        return float4(Map(color.rgb), 1f);
    #else
        static const float3x2 pSizes = float3x2(
            float2(0f, 1f / 256f),
            float2(0f, 1f / 64f),
            float2(0f, 1f / 16f)
        );

        float4 bloomColor = tex2D(Bloom, uv);
                
        //Finish up with vertical blurs for the extra bloom textures
        float gVal = NormalDist(0f, sigma);
        float3x3 cmat = float3x3(
            tex2D(B1, uv).rgb,
            tex2D(B2, uv).rgb,
            tex2D(B3, uv).rgb
        ) * gVal;

        float3x2 offsets = float3x2(0, 0, 0, 0, 0, 0);
        for (float i = 1; i <= BIRDHDR_BLOOM_SIZE; i++) {
            gVal = NormalDist(i, sigma);
            offsets += pSizes;

            cmat += float3x3(
                tex2D(B1, uv + offsets[0]).rgb + tex2D(B1, uv - offsets[0]).rgb,
                tex2D(B2, uv + offsets[1]).rgb + tex2D(B2, uv - offsets[1]).rgb,
                tex2D(B3, uv + offsets[2]).rgb + tex2D(B3, uv - offsets[2]).rgb
            ) * gVal;
        }
        
        //Compensation for not sampling to infinity
        cmat = cmat / 0.95f;
        
        bloomColor += cmat[0] * SpreadBias + cmat[1] * pow(SpreadBias, 2f) + cmat[2] * pow(SpreadBias, 3f);
        bloomColor *= intensity / 4f;

        #if BIRDHDR_BLOOM_SHOW_TEX
            return bloomColor;
        #else
            //Most tonemaps return gamma-space colors, but remapping to linear is handled in Map()
            return float4(Map(color.rgb + bloomColor.rgb), 1f);
        #endif
    #endif
    }

#if !BIRDHDR_MANUAL_EXPOSURE

    float PS_Adapt(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float currentBrightness = tex2Dlod(bhdr_Adapt, float4(uv, 0, 8)).r;
        float prevExposure = tex2D(bhdr_PrevExposure, float2(0f, 0f)).r;
        if (prevExposure == 0f) prevExposure = 1f;

        //Use gradient descent for adaptation
    #if BIRDHDR_SMART_ADAPTATION
        float target = tex2Dlod(bhdr_OriginalBrightness, float4(uv, 0, 8)).r;
        float delta = target * pow(2f, ExposureBias) - currentBrightness;;
        return max(prevExposure + delta * ExposureAdaptRate, 0.001f);
    #else
        float delta = ExposureTarget * pow(2f, ExposureBias) - currentBrightness;
        return clamp(prevExposure + delta * ExposureAdaptRate, MinExposure, MaxExposure);
    #endif
    }

    float PS_GatherAdapt(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  { return dot(tex2D(ReShade::BackBuffer, uv).rgb, float3(0.299f, 0.587f, 0.114f)); }
    float4 PS_Copy(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  { return tex2D(bhdr_Exposure, uv); }
#endif

    technique BirdsHDR <ui_tooltip = "Features independent bloom and tonemapping components.\n\n---Preprocessor definitions---\n\nBIRDHDR_BLOOM_ENABLED - (default: 1) Enables/Disables the bloom component.\n\tBIRDHDR_BLOOM_SIZE - (default: 3) Determines how far bloom spreads. Direct effect on performance and the size increase is non-linear.\n\tBIRDHDR_BLOOM_SHOW_TEX - (default: 0) View the bloom texture on its own.\n\nBIRDHDR_MANUAL_EXPOSURE - (default: 0) Enables/Disables automatic brightness adaptation.\nBIRDHDR_SMART_ADAPTATION - (default: 1) Smart adaptation adapts to the same overall brightness as before bloom.";> 
    {
    #if BIRDHDR_BLOOM_ENABLED
        pass gather {
            VertexShader = PostProcessVS;
            PixelShader = PS_Gather;
            RenderTarget = TEX_bhdr_Bloom;
        }

        pass multiblurX {
            VertexShader = PostProcessVS;
            PixelShader = PS_MultiBlurX;

            //Use the power of mipmapping and multiple render targets to blur to 3 textures at once.
            RenderTarget0 = TEX_B1;
            RenderTarget1 = TEX_B2;
            RenderTarget2 = TEX_B3;
        }
    #endif

    #if (!BIRDHDR_MANUAL_EXPOSURE) && BIRDHDR_SMART_ADAPTATION
        pass getoriginal {
            VertexShader = PostProcessVS;
            PixelShader = PS_GatherAdapt;
            RenderTarget = TEX_bhdr_OriginalBrightness;
        }
    #endif

        pass apply {
            VertexShader = PostProcessVS;
            PixelShader = PS_Apply;
        }

    #if !BIRDHDR_MANUAL_EXPOSURE
        pass gatherAdapt {
            VertexShader = PostProcessVS;
            PixelShader = PS_GatherAdapt;
            RenderTarget = TEX_bhdr_Adapt;
        }

        pass adapt {
            VertexShader = PostProcessVS;
            PixelShader = PS_Adapt;
            RenderTarget = TEX_bhdr_Exposure;
        }

        pass Copy {
            VertexShader = PostProcessVS;
            PixelShader = PS_Copy;
            RenderTarget = TEX_bhdr_PrevExposure;
        }
    #endif
    }
}