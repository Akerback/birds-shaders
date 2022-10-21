#pragma once

namespace BS_LIB {
    //No componentwise output
    float3 Sobel(sampler sm, float2 uv, float radius) {
        //Setup
        float2 ps = BUFFER_PIXEL_SIZE * radius;

        //Reused values
        float3 tl = tex2D(sm, uv + float2(-1, -1) * ps).rgb;
        float3 tr = tex2D(sm, uv + float2(1, -1) * ps).rgb;
        float3 bl = tex2D(sm, uv + float2(-1, 1) * ps).rgb;
        float3 br = tex2D(sm, uv + float2(1, 1) * ps).rgb;

        //Edge detection
        //Vertical = top - bottom
        float3 vertical =   tl
                            + tex2D(sm, uv + float2(0, -1) * ps).rgb * 2
                            + tr
                            - bl
                            - tex2D(sm, uv + float2(0, 1) * ps).rgb * 2
                            - br;

        //horisontal = left - right
        float3 horisontal = tl
                            + tex2D(sm, uv + float2(-1, 0) * ps).rgb * 2
                            + bl
                            - tr
                            - tex2D(sm, uv + float2(1, 0) * ps).rgb * 2
                            - br;

        //Map to 0-1 range
        float3 result = 0f;

        result.r = sqrt(horisontal.r * horisontal.r + vertical.r * vertical.r);
        result.g = sqrt(horisontal.g * horisontal.g + vertical.g * vertical.g);
        result.b = sqrt(horisontal.b * horisontal.b + vertical.b * vertical.b);

        return result;
    }
    
    //Componentwise output
    float3 Sobel(sampler sm, float2 uv, float radius, out float3 horisontalOutput, out float3 verticalOutput) {
        //Setup
        float2 ps = BUFFER_PIXEL_SIZE * radius;

        //Reused values
        float3 tl = tex2D(sm, uv + float2(-1, -1) * ps).rgb;
        float3 tr = tex2D(sm, uv + float2(1, -1) * ps).rgb;
        float3 bl = tex2D(sm, uv + float2(-1, 1) * ps).rgb;
        float3 br = tex2D(sm, uv + float2(1, 1) * ps).rgb;

        //--Edge detection
        //Vertical = top - bottom
        float3 vertical =   tl
                            + tex2D(sm, uv + float2(0, -1) * ps).rgb * 2
                            + tr
                            - bl
                            - tex2D(sm, uv + float2(0, 1) * ps).rgb * 2
                            - br;

        //horisontal = left - right
        float3 horisontal = tl
                            + tex2D(sm, uv + float2(-1, 0) * ps).rgb * 2
                            + bl
                            - tr
                            - tex2D(sm, uv + float2(1, 0) * ps).rgb * 2
                            - br;

        //Map to 0-1 range
        horisontalOutput = horisontal;
        verticalOutput = vertical;

        float3 result = 0f;

        result.r = sqrt(horisontal.r * horisontal.r + vertical.r * vertical.r);
        result.g = sqrt(horisontal.g * horisontal.g + vertical.g * vertical.g);
        result.b = sqrt(horisontal.b * horisontal.b + vertical.b * vertical.b);

        return result;
    }

    float GaussianFunction(float x, float y) {
        const float part_a = 0.7978845608f;

        return part_a * exp(-2f * (x * x + y * y));
    }

    float3 GaussianBlur(sampler sm, float2 uv, float radius, int sampleCount) {
        float2 ps = BUFFER_PIXEL_SIZE;

        float step_size_real = radius / sampleCount;

        float3 gaussAccum = 0f;
        float gaussValue = 0f;
        float accum = 0f;

        for (float x = -radius; x <= radius; x += step_size_real) {
            for (float y = -radius; y <= radius; y += step_size_real) {
                gaussValue = GaussianFunction(x / radius, y / radius);
                accum += gaussValue;

                gaussAccum += tex2D(sm, uv + float2(x, y) * ps).rgb * gaussValue;
            }
        }

        gaussAccum /= accum;

        return gaussAccum;
    }
}