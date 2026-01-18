//
//  HybridCameraVisionPixelColors.swift
//  CameraVisionPixelColors
//

import Foundation
import NitroModules

class HybridCameraVisionPixelColors: HybridCameraVisionPixelColorsSpec {
  func analyzeImageAsync(image: ImageData) throws -> Promise<PixelColorsResult> {
    return Promise { resolve, reject in
      DispatchQueue.global(qos: .userInitiated).async {
        let width = Int(image.width)
        let height = Int(image.height)
        let data = Data(image.data)

        let result = PixelAnalyzerEngine.shared.analyzeImageData(
          width: width,
          height: height,
          data: data
        )

        let uniqueColorCount = result["uniqueColorCount"] as? Int ?? 0
        let topColorsDict = result["topColors"] as? [[String: Int]] ?? []
        let brightestColorsDict = result["brightestColors"] as? [[String: Int]] ?? []

        let topColors = topColorsDict.map { dict in
          RGBColor(
            r: Double(dict["r"] ?? 0),
            g: Double(dict["g"] ?? 0),
            b: Double(dict["b"] ?? 0)
          )
        }

        let brightestColors = brightestColorsDict.map { dict in
          RGBColor(
            r: Double(dict["r"] ?? 0),
            g: Double(dict["g"] ?? 0),
            b: Double(dict["b"] ?? 0)
          )
        }

        let pixelColorsResult = PixelColorsResult(
          uniqueColorCount: Double(uniqueColorCount),
          topColors: topColors,
          brightestColors: brightestColors
        )

        resolve(pixelColorsResult)
      }
    }
  }
}
