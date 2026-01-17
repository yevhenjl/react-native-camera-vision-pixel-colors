package com.cameravisionpixelcolors

import android.graphics.Bitmap
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.max

object PixelAnalyzerEngine {
  private const val BUCKETS = 32 * 32 * 32
  private val executor = Executors.newSingleThreadExecutor()
  private val cachedResult = AtomicReference<Map<String, Any>>(mapOf(
    "uniqueColorCount" to 0,
    "topColors" to emptyList<Map<String, Int>>(),
    "brightestColors" to emptyList<Map<String, Int>>()
  ))

  private val histogram = IntArray(BUCKETS)
  private val brightnessSum = IntArray(BUCKETS)

  fun analyzeAsync(bitmap: Bitmap) {
    executor.execute {
      analyze(bitmap)
    }
  }

  fun analyzeSync(): Map<String, Any> {
    return cachedResult.get()
  }

  fun analyzeImageData(width: Int, height: Int, data: ByteArray): Map<String, Any> {
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(data))
    return analyzeImmediate(bitmap)
  }

  private fun analyzeImmediate(bitmap: Bitmap): Map<String, Any> {
    val width = bitmap.width
    val height = bitmap.height
    val size = width * height
    val pixels = IntArray(size)
    bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

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

    return mapOf(
      "uniqueColorCount" to uniqueCount,
      "topColors" to topColors.map { decode(it.first) },
      "brightestColors" to topBright.map { decode(it.first) }
    )
  }

  private fun analyze(bitmap: Bitmap) {
    val result = analyzeImmediate(bitmap)
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
