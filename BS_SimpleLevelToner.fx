#include "ReShade.fxh"
#include "ReShadeUI.fxh"

namespace BSSLT {
    #ifndef BSSLT_MANUAL_SHADOW_COLOR
        #define BSSLT_MANUAL_SHADOW_COLOR 0
    #endif

    #ifndef BSSLT_RETAIN_BRIGHTNESS
        #define BSSLT_RETAIN_BRIGHTNESS 1
    #endif

    #ifndef BSSLT_DEBUG_WEIGHTS
        #define BSSLT_DEBUG_WEIGHTS 0
    #endif

    uniform float effectIntensity <
        ui_type = "drag";
    > = 1f;

    uniform float maintainBW <
        ui_type = "drag";
    > = 1f;

    static const float4 highlightColor = float4(1, 1, 1, 1);

    uniform float4 midToneColor <
        ui_type = "color";
    > = float4(255f, 173f, 55f, 255f) / 255f;

#if BSSLT_MANUAL_SHADOW_COLOR
    uniform float4 shadowColor <
        ui_type = "color";
    > = float4(115f, 220f, 255f, 255f) / 255f;
#else
    float3 getShadowColor() {
        //Add 180 to the midtone color's hue
        float minimum = min(midToneColor.r, min(midToneColor.g, midToneColor.b));
        float maximum = max(midToneColor.r, max(midToneColor.g, midToneColor.b));

        float middle = (maximum + minimum) / 2f;

        return middle - (midToneColor - middle);
    }
#endif

    float4 PS_main(float4 p: SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
    {
        const float rootThree = pow(3f, 0.5f);

    #if !BSSLT_MANUAL_SHADOW_COLOR
        const float4 shadowColor = float4(getShadowColor(), 1f);
    #endif
        
        float4 color = tex2D(ReShade::BackBuffer, uv);
        float4 outputColor = color;
        
        float bwPreserve = (1 - distance(color.rgb, float3(1f, 1f, 1f)) / rootThree);

        float brightness = dot(color.rgb, float3(0.299, 0.587, 0.114));

        float highlight = brightness;
        float shadow = 1 - brightness;
        float midTone = 1 - abs(brightness - 0.5f) * 2;

    #if LEVELTONER_USE_EXPONENTIALS
        highlight = pow(highlight, highlightExponent);
        shadow = pow(shadow, shadowExponent);
        midTone = pow(midTone, midToneExponent);
    #endif

    #if BSSLT_DEBUG_WEIGHTS
        return float4(highlight, midTone, shadow, 1);
    #else

        //Multiplicative color mixing
        float totalPower = midToneColor.a * midTone + highlightColor.a * highlight + shadowColor.a * shadow;

        float3 colorFactor = midToneColor.rgb * midToneColor.a * midTone
                            +highlightColor.rgb * highlightColor.a * highlight
                            +shadowColor.rgb * shadowColor.a * shadow;
        
        if (totalPower != 0) colorFactor /= totalPower;
        else colorFactor = 1;

        color.rgb *= colorFactor;

    #if BSSLT_RETAIN_BRIGHTNESS
        float newBrightness = dot(color.rgb, float3(0.299, 0.587, 0.114));
        if (newBrightness > 0) color.rgb *= brightness / newBrightness;
    #endif

        outputColor = lerp(outputColor, color, max(0, effectIntensity - pow(abs(bwPreserve), 0.5f) * effectIntensity));

        return outputColor;
    #endif
    }

    technique BirdsSimpleColorGrading {
        pass main 
        {
            VertexShader = PostProcessVS;
            PixelShader = PS_main;
        }
    }
}