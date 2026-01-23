package com.cameravisionpixelcolors

import com.margelo.nitro.cameravisionpixelcolors.ColorInfo
import com.margelo.nitro.cameravisionpixelcolors.HybridCameraVisionPixelColorsSpec
import com.margelo.nitro.cameravisionpixelcolors.ImageData
import com.margelo.nitro.cameravisionpixelcolors.PixelColorsResult
import com.margelo.nitro.core.Promise

class HybridCameraVisionPixelColors: HybridCameraVisionPixelColorsSpec() {

    override fun analyzeImageAsync(image: ImageData): Promise<PixelColorsResult> {
        return Promise.async {
            val width = image.width.toInt()
            val height = image.height.toInt()
            val data = ByteArray(image.data.size.toInt())
            image.data.getBuffer(false).get(data)

            val result = PixelAnalyzerEngine.analyzeImageData(width, height, data)

            val uniqueColorCount = result["uniqueColorCount"] as? Int ?: 0
            @Suppress("UNCHECKED_CAST")
            val topColorsMap = result["topColors"] as? List<Map<String, Int>> ?: emptyList()
            @Suppress("UNCHECKED_CAST")
            val brightestColorsMap = result["brightestColors"] as? List<Map<String, Int>> ?: emptyList()

            val topColors = topColorsMap.map { map ->
                ColorInfo(
                    r = (map["r"] ?: 0).toDouble(),
                    g = (map["g"] ?: 0).toDouble(),
                    b = (map["b"] ?: 0).toDouble(),
                    hsv = null,
                    pixelPercentage = null
                )
            }.toTypedArray()

            val brightestColors = brightestColorsMap.map { map ->
                ColorInfo(
                    r = (map["r"] ?: 0).toDouble(),
                    g = (map["g"] ?: 0).toDouble(),
                    b = (map["b"] ?: 0).toDouble(),
                    hsv = null,
                    pixelPercentage = null
                )
            }.toTypedArray()

            PixelColorsResult(
                uniqueColorCount = uniqueColorCount.toDouble(),
                topColors = topColors,
                brightestColors = brightestColors,
                motion = null,
                roiApplied = null,
                totalPixelsAnalyzed = (width * height).toDouble()
            )
        }
    }
}
