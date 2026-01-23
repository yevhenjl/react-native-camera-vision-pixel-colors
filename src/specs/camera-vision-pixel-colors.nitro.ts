import { type HybridObject } from 'react-native-nitro-modules'

export type RGBColor = { r: number; g: number; b: number }

export type HSVColor = { h: number; s: number; v: number } // h:0-360, s:0-100, v:0-100

export type ColorInfo = {
  r: number
  g: number
  b: number
  hsv?: HSVColor // when enableHsvAnalysis=true
  pixelPercentage?: number // 0-1, when minPixelThreshold set
}

export type ROIConfig = {
  x: number // 0-1 normalized
  y: number // 0-1 normalized
  width: number // 0-1 normalized
  height: number // 0-1 normalized
}

export type AnalysisOptions = {
  enableMotionDetection?: boolean // default: false
  motionThreshold?: number // default: 0.1
  roi?: ROIConfig // if provided, analyze only this region
  maxTopColors?: number // default: 3, range: 1-10
  maxBrightestColors?: number // default: 3, range: 1-10
  enableHsvAnalysis?: boolean // default: false
  minPixelThreshold?: number // 0-1, e.g., 0.002 = 0.2%
}

export type MotionResult = {
  score: number // 0-1
  hasMotion: boolean // score > threshold
}

export type PixelColorsResult = {
  uniqueColorCount: number
  topColors: ColorInfo[] // extends RGBColor with optional hsv/pixelPercentage
  brightestColors: ColorInfo[] // extends RGBColor with optional hsv/pixelPercentage
  motion?: MotionResult // always present if enableMotionDetection=true
  roiApplied?: boolean // true if ROI config was provided
  totalPixelsAnalyzed?: number // for threshold context
}

export type ImageData = {
  width: number
  height: number
  data: ArrayBuffer
}

export interface CameraVisionPixelColors
  extends HybridObject<{ ios: 'swift'; android: 'kotlin' }> {
  analyzeImageAsync(image: ImageData): Promise<PixelColorsResult>
}
