import { type HybridObject } from 'react-native-nitro-modules'

export type RGBColor = { r: number; g: number; b: number }

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
}

export type MotionResult = {
  score: number // 0-1
  hasMotion: boolean // score > threshold
}

export type PixelColorsResult = {
  uniqueColorCount: number
  topColors: RGBColor[]
  brightestColors: RGBColor[]
  motion?: MotionResult // always present if enableMotionDetection=true
  roiApplied?: boolean // true if ROI config was provided
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
