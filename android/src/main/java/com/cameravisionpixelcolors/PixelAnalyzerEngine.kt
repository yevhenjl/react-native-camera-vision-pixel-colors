package com.cameravisionpixelcolors

import android.graphics.Bitmap
import android.graphics.Rect
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

data class AnalysisOptions(
  val enableMotionDetection: Boolean = false,
  val motionThreshold: Float = 0.1f,
  val roi: ROIConfig? = null
)

data class ROIConfig(
  val x: Float,
  val y: Float,
  val width: Float,
  val height: Float
)

object PixelAnalyzerEngine {
  private const val BUCKETS = 32 * 32 * 32
  private const val MAX_RAW_PIXEL_DIMENSION = 1920
  private val executor = Executors.newSingleThreadExecutor()
  private val cachedResult = AtomicReference<Map<String, Any>>(mapOf(
    "uniqueColorCount" to 0,
    "topColors" to emptyList<Map<String, Int>>(),
    "brightestColors" to emptyList<Map<String, Int>>()
  ))

  private val histogram = IntArray(BUCKETS)
  private val brightnessSum = IntArray(BUCKETS)

  // Motion detection state
  private var previousGrayscale: IntArray? = null
  private var previousWidth: Int = 0
  private var previousHeight: Int = 0

  fun analyzeAsync(bitmap: Bitmap, options: AnalysisOptions = AnalysisOptions()) {
    executor.execute {
      analyze(bitmap, options)
    }
  }

  fun analyzeSync(): Map<String, Any> {
    return cachedResult.get()
  }

  // Calculate ROI in pixel coordinates
  private fun calculateROI(config: ROIConfig, width: Int, height: Int): Rect {
    val x = (config.x * width).toInt()
    val y = (config.y * height).toInt()
    val w = max(1, (config.width * width).toInt())
    val h = max(1, (config.height * height).toInt())
    return Rect(x, y, min(x + w, width), min(y + h, height))
  }

  // Calculate motion score between current and previous frame
  private fun calculateMotion(bitmap: Bitmap, threshold: Float): Map<String, Any> {
    val width = bitmap.width
    val height = bitmap.height
    val totalPixels = width * height
    val pixels = IntArray(totalPixels)
    bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

    // Convert to grayscale
    val currentGrayscale = IntArray(totalPixels) { i ->
      val px = pixels[i]
      val r = (px shr 16) and 0xFF
      val g = (px shr 8) and 0xFF
      val b = px and 0xFF
      ((0.299 * r + 0.587 * g + 0.114 * b).toInt())
    }

    val prev = previousGrayscale
    if (prev == null || previousWidth != width || previousHeight != height) {
      // First frame - save and return zero motion
      previousGrayscale = currentGrayscale
      previousWidth = width
      previousHeight = height
      return mapOf("score" to 0.0, "hasMotion" to false)
    }

    // Count pixels exceeding threshold
    val thresholdValue = (threshold * 255).toInt()
    var changedCount = 0
    for (i in 0 until totalPixels) {
      if (abs(currentGrayscale[i] - prev[i]) > thresholdValue) {
        changedCount++
      }
    }

    val score = changedCount.toDouble() / totalPixels

    // Swap buffers
    previousGrayscale = currentGrayscale
    previousWidth = width
    previousHeight = height

    return mapOf("score" to score, "hasMotion" to (score > threshold))
  }

  // Extract raw RGBA pixels with optional scaling
  private fun extractRawPixels(bitmap: Bitmap, roi: Rect?): ByteBuffer? {
    var workBitmap = bitmap

    // Apply ROI if provided
    if (roi != null) {
      workBitmap = Bitmap.createBitmap(
        bitmap,
        roi.left,
        roi.top,
        roi.width(),
        roi.height()
      )
    }

    var width = workBitmap.width
    var height = workBitmap.height

    // Scale down if exceeds 1080p
    if (width > MAX_RAW_PIXEL_DIMENSION || height > MAX_RAW_PIXEL_DIMENSION) {
      val scale = min(
        MAX_RAW_PIXEL_DIMENSION.toFloat() / width,
        MAX_RAW_PIXEL_DIMENSION.toFloat() / height
      )
      val newWidth = (width * scale).toInt()
      val newHeight = (height * scale).toInt()
      workBitmap = Bitmap.createScaledBitmap(workBitmap, newWidth, newHeight, true)
      width = newWidth
      height = newHeight
    }

    // Extract RGBA data
    val pixels = IntArray(width * height)
    workBitmap.getPixels(pixels, 0, width, 0, 0, width, height)

    val buffer = ByteBuffer.allocateDirect(width * height * 4)
    for (px in pixels) {
      // ARGB -> RGBA conversion
      val a = (px shr 24) and 0xFF
      val r = (px shr 16) and 0xFF
      val g = (px shr 8) and 0xFF
      val b = px and 0xFF
      buffer.put(r.toByte())
      buffer.put(g.toByte())
      buffer.put(b.toByte())
      buffer.put(a.toByte())
    }
    buffer.rewind()

    return buffer
  }

  fun analyzeImageData(width: Int, height: Int, data: ByteArray): Map<String, Any> {
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(data))
    return analyzeImmediate(bitmap)
  }

  private fun analyzeImmediate(bitmap: Bitmap, options: AnalysisOptions = AnalysisOptions()): Map<String, Any> {
    var workBitmap = bitmap
    var roiRect: Rect? = null

    // Apply ROI if configured
    if (options.roi != null) {
      roiRect = calculateROI(options.roi, bitmap.width, bitmap.height)
      workBitmap = Bitmap.createBitmap(
        bitmap,
        roiRect.left,
        roiRect.top,
        roiRect.width(),
        roiRect.height()
      )
    }

    val width = workBitmap.width
    val height = workBitmap.height
    val size = width * height
    val pixels = IntArray(size)
    workBitmap.getPixels(pixels, 0, width, 0, 0, width, height)

    val localHistogram = IntArray(BUCKETS)
    val localBrightnessSum = IntArray(BUCKETS)

    for (px in pixels) {
      val r = (px shr 16) and 0xFF
      val g = (px shr 8) and 0xFF
      val b = px and 0xFF
      val rq = r shr 3
      val gq = g shr 3
      val bq = b shr 3
      val idx = (rq shl 10) or (gq shl 5) or bq
      localHistogram[idx]++
      val brightness = (2126 * r + 7152 * g + 722 * b) / 10000
      localBrightnessSum[idx] += brightness
    }

    val topColors = ArrayList<Pair<Int, Int>>(3)
    val topBright = ArrayList<Pair<Int, Int>>(3)
    var uniqueCount = 0
    for (i in 0 until BUCKETS) {
      val count = localHistogram[i]
      if (count == 0) continue
      uniqueCount++
      insertTop(topColors, i, count)
      val avgBrightness = localBrightnessSum[i] / max(count, 1)
      insertTop(topBright, i, avgBrightness)
    }

    fun decode(idx: Int): Map<String, Int> {
      return mapOf(
        "r" to ((idx shr 10) and 31 shl 3),
        "g" to ((idx shr 5) and 31 shl 3),
        "b" to ((idx and 31) shl 3)
      )
    }

    val result = mutableMapOf<String, Any>(
      "uniqueColorCount" to uniqueCount,
      "topColors" to topColors.map { decode(it.first) },
      "brightestColors" to topBright.map { decode(it.first) }
    )

    // Add ROI applied flag
    if (options.roi != null) {
      result["roiApplied"] = true
    }

    // Add motion detection if enabled
    if (options.enableMotionDetection) {
      val motionResult = calculateMotion(bitmap, options.motionThreshold)
      result["motion"] = motionResult
    }

    return result
  }

  private fun analyze(bitmap: Bitmap, options: AnalysisOptions = AnalysisOptions()) {
    val result = analyzeImmediate(bitmap, options)
    cachedResult.set(result)
  }

  private fun insertTop(list: MutableList<Pair<Int, Int>>, idx: Int, value: Int) {
    var i = 0
    while (i < list.size && value <= list[i].second) i++
    if (i < 3) {
      list.add(i, idx to value)
      if (list.size > 3) list.removeAt(3)
    }
  }
}
