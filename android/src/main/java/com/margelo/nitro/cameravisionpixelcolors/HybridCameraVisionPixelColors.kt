package com.margelo.nitro.cameravisionpixelcolors

import com.cameravisionpixelcolors.PixelAnalyzerEngine
import com.margelo.nitro.core.Promise
import java.util.concurrent.Executors

class HybridCameraVisionPixelColors: HybridCameraVisionPixelColorsSpec() {
    private val executor = Executors.newSingleThreadExecutor()

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
                RGBColor(
                    r = (map["r"] ?: 0).toDouble(),
                    g = (map["g"] ?: 0).toDouble(),
                    b = (map["b"] ?: 0).toDouble()
                )
            }.toTypedArray()

            val brightestColors = brightestColorsMap.map { map ->
                RGBColor(
                    r = (map["r"] ?: 0).toDouble(),
                    g = (map["g"] ?: 0).toDouble(),
                    b = (map["b"] ?: 0).toDouble()
                )
            }.toTypedArray()

            PixelColorsResult(
                uniqueColorCount = uniqueColorCount.toDouble(),
                topColors = topColors,
                brightestColors = brightestColors,
                motion = null,
                roiApplied = null
            )
        }
    }
}
