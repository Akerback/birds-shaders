#include "ReShade.fxh"

namespace BirdsColorAnalysisNamespace {
    uniform int ReportAreaGridDivisions <
        ui_type = "drag";
        ui_min = 1;
    > = 4;

    uniform float2 ReportAreaSize <
        ui_type = "drag";
    > = float2(0.45f, 0.8f);

    uniform int2 ReportAreaMargin <
        ui_type = "drag";
    > = 16;

    uniform uint Mode <
        ui_type = "combo";
        ui_items = "Overall\0RedDelta\0GreenDelta\0BlueDelta\0";
    > = 0;

    uniform int GraphThickness <
        ui_type = "drag";
    > = 4;

    uniform float GraphSaturation <
        ui_type = "drag";
    > = 0.75f;

    #define IsWithin(a, b, tolerance) any(abs(a - b) <= tolerance)
    #define IsPointInArea(uv, areaStart, areaEnd) (((uv.x >= areaStart.x) && (uv.x <= areaEnd.x)) && ((uv.y >= areaStart.y) && (uv.y <= areaEnd.y)))
    #define IsPointInBounds(uv) (((uv.x >= 0f) && (uv.x <= 1f)) && ((uv.y >= 0f) && (uv.y <= 1f)))

    float2 ScreenToGraphUV(float2 uv) {
        float2 ReportAreaOrigin = (float2(1f, 1f) - ReportAreaSize) + BUFFER_PIXEL_SIZE * ReportAreaMargin;
        float2 ReportAreaEndpoint = float2(1f, 1f) - BUFFER_PIXEL_SIZE * ReportAreaMargin;
        float2 ReportAreaSizeAdjusted = ReportAreaEndpoint - ReportAreaOrigin;

        float2 graphuv = (uv - ReportAreaOrigin) * float2(1f / ReportAreaSizeAdjusted.x, 1f / ReportAreaSizeAdjusted.y);
        return graphuv;
    }

    float4 PS_drawSamplingArea(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        float4 color = tex2D(ReShade::BackBuffer, uv);

        float3 SamplingColor = float3(1f, 1f, 1f);

        switch (Mode) {
            case 1:
                SamplingColor = float3(1f, 0f, 0f);
                break;
            case 2:
                SamplingColor = float3(0f, 1f, 0f);
                break;
            case 3:
                SamplingColor = float3(0f, 0f, 1f);
                break;
            default:
                break;
        }

        if (uv.y <= BUFFER_PIXEL_SIZE.y * 4f) return float4(SamplingColor * uv.x, 1f);

        return color;
    }

    float4 PS_drawGraphBG(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        if (uv.y <= BUFFER_PIXEL_SIZE.y * 8f) discard;

        float4 color = tex2D(ReShade::BackBuffer, uv);
        float2 graphUV = ScreenToGraphUV(uv);

        if (IsPointInBounds(graphUV)) {
            float2 nearestGridPoint = round(graphUV * ReportAreaGridDivisions) / ReportAreaGridDivisions;
            if (IsWithin(graphUV, nearestGridPoint, BUFFER_PIXEL_SIZE * 2)) return float4(0f, 0f, 0f, 1f);
            if ((Mode == 0) && IsWithin(1f - graphUV.x, graphUV.y, BUFFER_PIXEL_SIZE * 2)) return float4(0f, 0f, 0f, 1f);
            else if (IsWithin(graphUV.y, 0.5f, BUFFER_PIXEL_SIZE.y * 4)) return float4(0f, 0f, 0f, 1f);

            return float4(0.25f, 0.25f, 0.25f, 1f);
        }

        return color;
    }

    float4 PS_drawGraph(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET  {
        if (uv.y <= BUFFER_PIXEL_SIZE.y * 8f) discard;

        float4 color = tex2D(ReShade::BackBuffer, uv);
        float2 graphUV = ScreenToGraphUV(uv);
        float4 SampledColor = tex2D(ReShade::BackBuffer, float2(graphUV.x, 0f));

        if (IsPointInBounds(graphUV)) {
            float3 AccumulatedGraphColor = 0f;
            float3 target = graphUV.x;
            float3 delta = 0f;

            switch (Mode) {
                case 1:
                    target = (SampledColor - float3(graphUV.x, 0f, 0f)) * 0.5f + 0.5f;
                    break;
                case 2:
                    target = (SampledColor - float3(0f, graphUV.x, 0f)) * 0.5f + 0.5f;
                    break;
                case 3:
                    target = (SampledColor - float3(0f, 0f, graphUV.x)) * 0.5f + 0.5f;
                    break;
                default:
                    target = SampledColor.rgb;
                    break;
            }

            if (IsWithin(1f - graphUV.y, target.r, GraphThickness * BUFFER_PIXEL_SIZE.y)) AccumulatedGraphColor.r = 1f;
            if (IsWithin(1f - graphUV.y, target.g, GraphThickness * BUFFER_PIXEL_SIZE.y)) AccumulatedGraphColor.g = 1f;
            if (IsWithin(1f - graphUV.y, target.b, GraphThickness * BUFFER_PIXEL_SIZE.y)) AccumulatedGraphColor.b = 1f;

            if (any(AccumulatedGraphColor > 0f)) return float4(AccumulatedGraphColor + (1f - GraphSaturation), 1f);
        }

        return color;
    }

    technique ColorAnalysisPrep {
        pass sampleColors {
            VertexShader = PostProcessVS;
            PixelShader = PS_drawSamplingArea;
        }
    }

    technique ColorAnalysisReport {
        pass showReport {
            VertexShader = PostProcessVS;
            PixelShader = PS_drawGraphBG;
        }

        pass showGraph {
            VertexShader = PostProcessVS;
            PixelShader = PS_drawGraph;
        }
    }
}