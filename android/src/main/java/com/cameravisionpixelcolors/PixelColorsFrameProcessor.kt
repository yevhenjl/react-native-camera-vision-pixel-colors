package com.cameravisionpixelcolors

import com.mrousavy.camera.frameprocessors.Frame
import com.mrousavy.camera.frameprocessors.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessors.VisionCameraProxy

class PixelColorsFrameProcessor(proxy: VisionCameraProxy, options: Map<String, Any>?) : FrameProcessorPlugin() {
  override fun callback(frame: Frame, arguments: Map<String, Any>?): Any {
    val image = frame.image ?: return emptyMap<String, Any>()
    val bitmap = YuvToBitmapConverter.convert(image)
    PixelAnalyzerEngine.analyzeAsync(bitmap)
    return PixelAnalyzerEngine.analyzeSync()
  }
}
