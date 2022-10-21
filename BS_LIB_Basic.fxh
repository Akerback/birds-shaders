#pragma once

namespace BS_LIB {
    float Grayscale(float3 inputColor) {
        const float3 grayscaler = float3(0.299f, 0.587f, 0.114f);

        return dot(inputColor, grayscaler);
    }

    float3 HSVtoRGB(float3 hsvColor) {
        const float oneSixth = 1f / 6f;
        const float oneThird = 1f / 3f;

        float3 result = 0f;

        float correctedHue = (hsvColor.x + oneSixth) % 1f;

        int hueSection = correctedHue * 3;
        float progress = ((correctedHue * 6f) % 2f);

        float prevProg = max(0f, 1f - progress);
        float nextProg = max(0f, progress - 1f);

        switch (hueSection) {
            default:
                result = float3(1, nextProg, prevProg);
                //result = float3(1, 0, 0);
                break;
            case 1:
                result = float3(prevProg, 1, nextProg);
                //result = float3(0, 1, 0);
                break;
            case 2:
                result = float3(nextProg, prevProg, 1);
                //result = float3(0, 0, 1);
                break;
        }

        float range = 1f - hsvColor.y;

        result = result * hsvColor.y + range;

        return result * hsvColor.z;
    }

    float3 RGBtoHSV(float3 rgbColor) {
        const float oneSixth = 1f / 6f;

        float V = max(rgbColor.r, max(rgbColor.g, rgbColor.b));
        float minimum = min(rgbColor.r, min(rgbColor.g, rgbColor.b));

        float range = V - minimum;
        
        //Grayscale color, return grayscale with value
        if (range == 0f) return float3(0f, 0f, V);

        float3 clampedColor = (rgbColor - minimum) / range;

        //Hue
        float H = 0f;

        if (rgbColor.r == V) {
            H = oneSixth * (clampedColor.g - clampedColor.b);
        }
        if (rgbColor.g == V) {
            H = oneSixth * (2 + clampedColor.b - clampedColor.r);
        }
        if (rgbColor.b == V) {
            H = oneSixth * (4 + clampedColor.r - clampedColor.g);
        }

        if (H < 0f) H += 1f;

        //Saturation
        float S = 0;
        if (V != 0) S = range / V;

        return float3(H, S, V);
    }
}