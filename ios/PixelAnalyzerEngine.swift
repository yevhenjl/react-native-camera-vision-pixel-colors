import Foundation
import CoreImage
import CoreVideo
import UIKit

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
  func analyzeAsync(pixelBuffer: CVPixelBuffer) {
    gpuQueue.async { [weak self] in
      guard let self = self else { return }
      let result = self.fullAnalysis(pixelBuffer: pixelBuffer)
      self.cacheQueue.async {
        self.cachedResult = result
      }
    }
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

  private func fullAnalysis(pixelBuffer: CVPixelBuffer) -> [String: Any] {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
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

  private func reduceHistogram(_ data: [UInt32]) -> [String: Any] {
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

    let top = stats.sorted { $0.count > $1.count }.prefix(3).map { ["r": $0.r, "g": $0.g, "b": $0.b] }
    let bright = stats.sorted { $0.brightness > $1.brightness }.prefix(3).map { ["r": $0.r, "g": $0.g, "b": $0.b] }

    return [
      "uniqueColorCount": stats.count,
      "topColors": Array(top),
      "brightestColors": Array(bright)
    ]
  }
}
