package com.cameravisionpixelcolors

import com.mrousavy.camera.frameprocessors.Frame
import com.mrousavy.camera.frameprocessors.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessors.VisionCameraProxy

class PixelColorsFrameProcessor(proxy: VisionCameraProxy, options: Map<String, Any>?) : FrameProcessorPlugin() {
  override fun callback(frame: Frame, arguments: Map<String, Any>?): Any {
    val image = frame.image ?: return emptyMap<String, Any>()
    val bitmap = YuvToBitmapConverter.convert(image)

    // Parse options from arguments
    val analysisOptions = parseOptions(arguments)

    PixelAnalyzerEngine.analyzeAsync(bitmap, analysisOptions)
    return PixelAnalyzerEngine.analyzeSync()
  }

  private fun parseOptions(arguments: Map<String, Any>?): AnalysisOptions {
    val optionsMap = arguments?.get("options") as? Map<*, *> ?: return AnalysisOptions()

    val enableMotionDetection = optionsMap["enableMotionDetection"] as? Boolean ?: false
    val motionThreshold = (optionsMap["motionThreshold"] as? Number)?.toFloat() ?: 0.1f

    val roiMap = optionsMap["roi"] as? Map<*, *>
    val roi = if (roiMap != null) {
      val x = (roiMap["x"] as? Number)?.toFloat() ?: 0f
      val y = (roiMap["y"] as? Number)?.toFloat() ?: 0f
      val width = (roiMap["width"] as? Number)?.toFloat() ?: 1f
      val height = (roiMap["height"] as? Number)?.toFloat() ?: 1f
      ROIConfig(x, y, width, height)
    } else null

    val maxTopColors = (optionsMap["maxTopColors"] as? Number)?.toInt() ?: 3
    val maxBrightestColors = (optionsMap["maxBrightestColors"] as? Number)?.toInt() ?: 3

    return AnalysisOptions(
      enableMotionDetection = enableMotionDetection,
      motionThreshold = motionThreshold,
      roi = roi,
      maxTopColors = maxTopColors,
      maxBrightestColors = maxBrightestColors
    )
  }
}
