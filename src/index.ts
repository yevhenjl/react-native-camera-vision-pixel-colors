import { NitroModules } from 'react-native-nitro-modules'
import { VisionCameraProxy, type Frame } from 'react-native-vision-camera'
import type {
  CameraVisionPixelColors as CameraVisionPixelColorsSpec,
  PixelColorsResult,
  RGBColor,
  HSVColor,
  ColorInfo,
  ImageData,
  ROIConfig,
  AnalysisOptions,
  MotionResult,
} from './specs/camera-vision-pixel-colors.nitro'

// Nitro HybridObject for async image analysis
export const CameraVisionPixelColors =
  NitroModules.createHybridObject<CameraVisionPixelColorsSpec>(
    'CameraVisionPixelColors'
  )

// Frame Processor plugin for real-time analysis
const plugin = VisionCameraProxy.initFrameProcessorPlugin('pixelColors', {})

export function analyzePixelColors(
  frame: Frame,
  options?: AnalysisOptions
): PixelColorsResult {
  'worklet'
  if (!plugin) {
    throw new Error('pixelColors frame processor plugin is not available')
  }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return plugin.call(frame, { options } as any) as unknown as PixelColorsResult
}

// Re-export types
export type {
  PixelColorsResult,
  RGBColor,
  HSVColor,
  ColorInfo,
  ImageData,
  ROIConfig,
  AnalysisOptions,
  MotionResult,
}
