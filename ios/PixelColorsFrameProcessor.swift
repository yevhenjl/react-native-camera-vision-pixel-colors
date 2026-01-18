import VisionCamera
import CoreMedia

@objc(PixelColorsFrameProcessor)
public final class PixelColorsFrameProcessor: FrameProcessorPlugin {
  public override init(proxy: VisionCameraProxyHolder, options: [AnyHashable : Any]! = [:]) {
    super.init(proxy: proxy, options: options)
  }

  public override func callback(_ frame: Frame, withArguments arguments: [AnyHashable : Any]?) -> Any {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer) else {
      return PixelAnalyzerEngine.shared.analyzeSync()
    }

    // Parse options from arguments
    let options = parseOptions(from: arguments)

    // Fire & forget GPU pipeline
    PixelAnalyzerEngine.shared.analyzeAsync(pixelBuffer: pixelBuffer, options: options)
    // Return latest cached result synchronously
    return PixelAnalyzerEngine.shared.analyzeSync()
  }

  private func parseOptions(from arguments: [AnyHashable: Any]?) -> AnalysisOptionsNative {
    var options = AnalysisOptionsNative()

    guard let args = arguments,
          let optionsDict = args["options"] as? [String: Any] else {
      return options
    }

    if let enableMotionDetection = optionsDict["enableMotionDetection"] as? Bool {
      options.enableMotionDetection = enableMotionDetection
    }

    if let motionThreshold = optionsDict["motionThreshold"] as? Double {
      options.motionThreshold = Float(motionThreshold)
    }

    if let roiDict = optionsDict["roi"] as? [String: Any],
       let x = roiDict["x"] as? Double,
       let y = roiDict["y"] as? Double,
       let width = roiDict["width"] as? Double,
       let height = roiDict["height"] as? Double {
      options.roi = (x: Float(x), y: Float(y), width: Float(width), height: Float(height))
    }

    return options
  }
}
