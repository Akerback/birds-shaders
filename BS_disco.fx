#include "ReShade.fxh"

uniform float bd_time <source = "timer";>;

uniform float bd_intensity <
    ui_label = "Intensity";
    ui_type = "drag";
    ui_step = 0.01f;
> = 1.0f;

uniform float bd_speed <
    ui_label = "Speed";
    ui_type = "drag";
    ui_step = 0.01f;
    ui_max = 1.5f;
> = 0.25f;

uniform float bd_exponent <
    ui_label = "Weight exponent";
    ui_tooltip = "Higher values limit the effect to brighter colors.";
    ui_type = "drag";
    ui_step = 0.01f;
> = 3.0f;

uniform float bd_banding <
    ui_label = "Banding";
    ui_tooltip = "Higher values makes colors repeat more frequently.";
    ui_type = "drag";
    ui_step = 0.01f;
> = 3.0f;

uniform float2 bd_bandingFocalPoint <
    ui_label = "Banding focal point";
    ui_type = "drag";
    ui_step = 0.01f;
> = float2(0.5f, 0.0f);

float3 bd_colorFromHue(float hue) {
    static float sixtyDegrees = 1f / 6f;

    float3 color = float3(1f, 0f, 0f);
    
    int section    = floor(hue / sixtyDegrees);
    float progress =  frac(hue / sixtyDegrees);

    //return section / 6f;
    switch (section) {
        case 0:
            color = float3(1f, progress, 0f);
            break;
        case 1:
            color = float3(1f - progress, 1f, 0f);
            break;
        case 2:
            color = float3(0f, 1f, progress);
            break;
        case 3:
            color = float3(0f, 1f - progress, 1f);
            break;
        case 4:
            color = float3(progress, 0f, 1f);
            break;
        case 5:
            color = float3(1f, 0f, 1f - progress);
            break;
        default:
            break;
    }

    return color;
}

float4 bd_mainPS(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
    float4 color = tex2D(ReShade::BackBuffer, uv);

    float discoHue = (((bd_time + distance(uv, bd_bandingFocalPoint) * bd_banding * 1000f) * bd_speed) % 1000) / 1000f;

    float3 discoColor = bd_colorFromHue(discoHue);

    discoColor *= color.rgb;

    float weight = max(color.r, max(color.g, color.b));
    color.rgb = lerp(color.rgb, discoColor, pow(weight, bd_exponent) * bd_intensity);

    return color;
}

technique BirdsDisco {
    pass main {
        VertexShader = PostProcessVS;
        PixelShader = bd_mainPS;
    }
}