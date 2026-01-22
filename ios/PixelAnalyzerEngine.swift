import Foundation
import CoreImage
import CoreVideo
import UIKit
import Accelerate

struct AnalysisOptionsNative {
  var enableMotionDetection: Bool = false
  var motionThreshold: Float = 0.1
  var roi: (x: Float, y: Float, width: Float, height: Float)?
  var maxTopColors: Int = 3
  var maxBrightestColors: Int = 3
}

final class PixelAnalyzerEngine {
  static let shared = PixelAnalyzerEngine()
  private let gpuQueue = DispatchQueue(label: "pixel.colors.gpu", qos: .userInitiated)
  private let cacheQueue = DispatchQueue(label: "pixel.colors.cache")
  private let ciContext: CIContext
  private var cachedResult: [String: Any] = [
    "uniqueColorCount": 0,
    "topColors": [[String: Int]](),
    "brightestColors": [[String: Int]]()
  ]
  private let histogramBins: Int = 64
  private let maxRawPixelDimension: Int = 1920

  // Motion detection state
  private var previousGrayscale: [UInt8]?
  private var previousWidth: Int = 0
  private var previousHeight: Int = 0

  private init() {
    self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
  }

  // Frame processor fast read (sync)
  func analyzeSync() -> [String: Any] {
    var result: [String: Any] = [:]
    cacheQueue.sync {
      result = self.cachedResult
    }
    return result
  }

  // Async full analysis (GPU)
  func analyzeAsync(pixelBuffer: CVPixelBuffer, options: AnalysisOptionsNative = AnalysisOptionsNative()) {
    gpuQueue.async { [weak self] in
      guard let self = self else { return }
      let result = self.fullAnalysis(pixelBuffer: pixelBuffer, options: options)
      self.cacheQueue.async {
        self.cachedResult = result
      }
    }
  }

  // MARK: - ROI Calculation

  private func calculateROI(config: (x: Float, y: Float, width: Float, height: Float), width: Int, height: Int) -> CGRect {
    let x = Int(config.x * Float(width))
    let y = Int(config.y * Float(height))
    let w = Int(config.width * Float(width))
    let h = Int(config.height * Float(height))
    return CGRect(x: x, y: y, width: max(1, w), height: max(1, h))
  }

  // MARK: - Motion Detection

  private func calculateMotion(pixelBuffer: CVPixelBuffer, threshold: Float) -> [String: Any] {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let totalPixels = width * height

    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      return ["score": 0.0, "hasMotion": false]
    }

    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

    // Convert to grayscale
    var currentGrayscale = [UInt8](repeating: 0, count: totalPixels)

    if pixelFormat == kCVPixelFormatType_32BGRA || pixelFormat == kCVPixelFormatType_32ARGB {
      // BGRA/ARGB format
      for y in 0..<height {
        let rowPtr = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
        for x in 0..<width {
          let offset = x * 4
          let b = Float(rowPtr[offset])
          let g = Float(rowPtr[offset + 1])
          let r = Float(rowPtr[offset + 2])
          currentGrayscale[y * width + x] = UInt8(0.299 * r + 0.587 * g + 0.114 * b)
        }
      }
    } else {
      // Fallback for other formats - use first channel
      for y in 0..<height {
        let rowPtr = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
        for x in 0..<width {
          currentGrayscale[y * width + x] = rowPtr[x * 4]
        }
      }
    }

    // Compare with previous frame
    guard let previous = previousGrayscale,
          previousWidth == width,
          previousHeight == height else {
      // First frame - save and return zero motion
      previousGrayscale = currentGrayscale
      previousWidth = width
      previousHeight = height
      return ["score": 0.0, "hasMotion": false]
    }

    // Calculate motion using vDSP for performance
    var current = currentGrayscale.map { Float($0) }
    var prev = previous.map { Float($0) }
    var diff = [Float](repeating: 0, count: totalPixels)

    // Calculate absolute difference
    vDSP_vsub(prev, 1, current, 1, &diff, 1, vDSP_Length(totalPixels))
    vDSP_vabs(diff, 1, &diff, 1, vDSP_Length(totalPixels))

    // Count pixels exceeding threshold
    let thresholdValue = threshold * 255
    var changedCount: Float = 0
    for value in diff {
      if value > thresholdValue {
        changedCount += 1
      }
    }

    let score = Double(changedCount) / Double(totalPixels)

    // Swap buffers
    previousGrayscale = currentGrayscale
    previousWidth = width
    previousHeight = height

    return ["score": score, "hasMotion": score > Double(threshold)]
  }

  // MARK: - Raw Pixel Extraction

  private func extractRawPixels(pixelBuffer: CVPixelBuffer, roi: CGRect?) -> Data? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    var width = CVPixelBufferGetWidth(pixelBuffer)
    var height = CVPixelBufferGetHeight(pixelBuffer)

    // Apply ROI if provided
    let extractRect: CGRect
    if let roi = roi {
      extractRect = CGRect(
        x: max(0, min(Int(roi.origin.x), width - 1)),
        y: max(0, min(Int(roi.origin.y), height - 1)),
        width: max(1, min(Int(roi.width), width - Int(roi.origin.x))),
        height: max(1, min(Int(roi.height), height - Int(roi.origin.y)))
      )
      width = Int(extractRect.width)
      height = Int(extractRect.height)
    } else {
      extractRect = CGRect(x: 0, y: 0, width: width, height: height)
    }

    // Scale down if exceeds 1080p
    var scale: Float = 1.0
    if width > maxRawPixelDimension || height > maxRawPixelDimension {
      let widthScale = Float(maxRawPixelDimension) / Float(width)
      let heightScale = Float(maxRawPixelDimension) / Float(height)
      scale = min(widthScale, heightScale)
    }

    let outputWidth = Int(Float(width) * scale)
    let outputHeight = Int(Float(height) * scale)

    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      return nil
    }

    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let srcWidth = CVPixelBufferGetWidth(pixelBuffer)

    // Extract RGBA data
    var rgbaData = Data(capacity: outputWidth * outputHeight * 4)

    for outY in 0..<outputHeight {
      let srcY = Int(extractRect.origin.y) + Int(Float(outY) / scale)
      let rowPtr = baseAddress.advanced(by: srcY * bytesPerRow).assumingMemoryBound(to: UInt8.self)

      for outX in 0..<outputWidth {
        let srcX = Int(extractRect.origin.x) + Int(Float(outX) / scale)
        let offset = srcX * 4

        // BGRA -> RGBA conversion
        let b = rowPtr[offset]
        let g = rowPtr[offset + 1]
        let r = rowPtr[offset + 2]
        let a = rowPtr[offset + 3]

        rgbaData.append(r)
        rgbaData.append(g)
        rgbaData.append(b)
        rgbaData.append(a)
      }
    }

    return rgbaData
  }

  // Analyze raw image data
  func analyzeImageData(width: Int, height: Int, data: Data) -> [String: Any] {
    guard let cgImage = createCGImage(width: width, height: height, data: data) else {
      return [
        "uniqueColorCount": 0,
        "topColors": [[String: Int]](),
        "brightestColors": [[String: Int]]()
      ]
    }
    return analyzeFromCGImage(cgImage)
  }

  private func createCGImage(width: Int, height: Int, data: Data) -> CGImage? {
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard let provider = CGDataProvider(data: data as CFData) else { return nil }

    return CGImage(
      width: width,
      height: height,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: bytesPerRow,
      space: colorSpace,
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: .defaultIntent
    )
  }

  private func analyzeFromCGImage(_ cgImage: CGImage) -> [String: Any] {
    let ciImage = CIImage(cgImage: cgImage)
    guard let histogram = CIFilter(name: "CIAreaHistogram",
                                   parameters: ["inputImage": ciImage,
                                                "inputCount": histogramBins,
                                                "inputExtent": CIVector(cgRect: ciImage.extent),
                                                "inputScale": 1.0])?.outputImage else {
      return [
        "uniqueColorCount": 0,
        "topColors": [[String: Int]](),
        "brightestColors": [[String: Int]]()
      ]
    }

    let bitmapSize = histogramBins * 4
    var bitmap = [UInt32](repeating: 0, count: bitmapSize)
    ciContext.render(histogram,
                     toBitmap: &bitmap,
                     rowBytes: bitmapSize * MemoryLayout<UInt32>.size,
                     bounds: CGRect(x: 0, y: 0, width: histogramBins, height: 1),
                     format: .RGBA32,
                     colorSpace: CGColorSpaceCreateDeviceRGB())

    return reduceHistogram(bitmap)
  }

  private func fullAnalysis(pixelBuffer: CVPixelBuffer, options: AnalysisOptionsNative = AnalysisOptionsNative()) -> [String: Any] {
    var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)

    // Apply ROI if configured
    var roiRect: CGRect?
    if let roi = options.roi {
      roiRect = calculateROI(config: roi, width: width, height: height)
      ciImage = ciImage.cropped(to: roiRect!)
    }

    guard let histogram = CIFilter(name: "CIAreaHistogram",
                                   parameters: ["inputImage": ciImage,
                                                "inputCount": histogramBins,
                                                "inputExtent": CIVector(cgRect: ciImage.extent),
                                                "inputScale": 1.0])?.outputImage else {
      return [
        "uniqueColorCount": 0,
        "topColors": [[String: Int]](),
        "brightestColors": [[String: Int]]()
      ]
    }

    let bitmapSize = histogramBins * 4
    var bitmap = [UInt32](repeating: 0, count: bitmapSize)
    ciContext.render(histogram,
                     toBitmap: &bitmap,
                     rowBytes: bitmapSize * MemoryLayout<UInt32>.size,
                     bounds: CGRect(x: 0, y: 0, width: histogramBins, height: 1),
                     format: .RGBA32,
                     colorSpace: CGColorSpaceCreateDeviceRGB())

    var result = reduceHistogram(bitmap, maxTopColors: options.maxTopColors, maxBrightestColors: options.maxBrightestColors)

    // Add ROI applied flag
    if options.roi != nil {
      result["roiApplied"] = true
    }

    // Add motion detection if enabled
    if options.enableMotionDetection {
      let motionResult = calculateMotion(pixelBuffer: pixelBuffer, threshold: options.motionThreshold)
      result["motion"] = motionResult
    }

    return result
  }

  private func reduceHistogram(_ data: [UInt32], maxTopColors: Int = 3, maxBrightestColors: Int = 3) -> [String: Any] {
    struct Stat { let r: Int; let g: Int; let b: Int; let count: Int; let brightness: Float }
    var stats: [Stat] = []
    for i in stride(from: 0, to: data.count, by: 4) {
      let r = Int(data[i])
      let g = Int(data[i + 1])
      let b = Int(data[i + 2])
      let count = Int(data[i + 3])
      if count == 0 { continue }
      let brightness = 0.299 * Float(r) + 0.587 * Float(g) + 0.114 * Float(b)
      stats.append(Stat(r: r, g: g, b: b, count: count, brightness: brightness))
    }

    let clampedTop = max(1, min(10, maxTopColors))
    let clampedBright = max(1, min(10, maxBrightestColors))
    let top = stats.sorted { $0.count > $1.count }.prefix(clampedTop).map { ["r": $0.r, "g": $0.g, "b": $0.b] }
    let bright = stats.sorted { $0.brightness > $1.brightness }.prefix(clampedBright).map { ["r": $0.r, "g": $0.g, "b": $0.b] }

    return [
      "uniqueColorCount": stats.count,
      "topColors": Array(top),
      "brightestColors": Array(bright)
    ]
  }
}
