import { type HybridObject } from 'react-native-nitro-modules'

export type RGBColor = { r: number; g: number; b: number }

export type PixelColorsResult = {
  uniqueColorCount: number
  topColors: RGBColor[]
  brightestColors: RGBColor[]
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
