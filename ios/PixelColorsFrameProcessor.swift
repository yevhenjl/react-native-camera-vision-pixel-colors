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
    // Fire & forget GPU pipeline
    PixelAnalyzerEngine.shared.analyzeAsync(pixelBuffer: pixelBuffer)
    // Return latest cached result synchronously
    return PixelAnalyzerEngine.shared.analyzeSync()
  }
}
