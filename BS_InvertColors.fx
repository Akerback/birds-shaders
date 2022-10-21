#include "ReShade.fxh"

namespace BSIC {
    #ifndef BSIC_INVERT_HUE_ONLY
        #define BSIC_INVERT_HUE_ONLY 1
    #endif

    uniform uint bsic_invert <
        ui_label = "Inversion mode";
        ui_type = "combo";
        ui_items = "Everything\0Hue\0Saturation\0Value\0";
    > = 0;

    float4 sample_emptyPS(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float4 color = tex2D(ReShade::BackBuffer, uv);

        float minimum = 0f;
        float maximum = 1f;

        switch (bsic_invert) {
            default:
                return float4(1f - color.rgb, 1f);
            case 1:
                minimum = min(color.r, min(color.g, color.b));
                maximum = max(color.r, max(color.g, color.b));

                float midpoint = (maximum + minimum) / 2f;

                return float4(midpoint - (color.rgb - midpoint), 1f);
            case 2:
                minimum = min(color.r, min(color.g, color.b));
                maximum = max(color.r, max(color.g, color.b));

                float range = maximum - minimum;

                float3 flippedAroundMax = (maximum - color.rgb);
                if (range > 0f) {
                    float rangeScaler = (1f - range) / range;

                    return float4(maximum - flippedAroundMax * rangeScaler, 1f);
                }
                break;
            case 3:
                maximum = max(color.r, max(color.g, color.b));
                
                if (maximum > 0f) return float4(color.rgb / maximum * (1f - maximum), 1f);
                return float4(1f, 1f, 1f, 1f);
        }
        
        return color;
    }

    technique BirdsColorInversion {
        pass main {
            VertexShader = PostProcessVS;
            PixelShader = sample_emptyPS;
        }
    }
}