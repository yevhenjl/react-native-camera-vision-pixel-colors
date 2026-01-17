# react-native-camera-vision-pixel-colors

High-performance **Vision Camera Frame Processor** for React Native (Expo compatible) that analyzes pixel colors **in real time**.
This plugin extracts:
- **Top 3 most frequent colors (RGB)**
- **Top 3 brightest colors (RGB)**
- **Total number of unique colors**
- **ROI analysis (configurable region)**
- **Motion detection (frame diff)**

It is implemented using **Nitro Modules** and runs **synchronously on the native thread** for use as a Vision Camera frame processor, while also exposing an async Nitro API for offline image analysis.

---

## Features
- Real-time processing (frame processor, synchronous)
- Color frequency analysis
- Brightness-based color ranking
- ROI analysis (configurable region)
- Motion detection (frame diff)
- Works directly on camera frames (Vision Camera)
- Written in **Swift (iOS)** and **Kotlin (Android)**
- Expo compatible via Config Plugin
- Minimal JS bridge overhead during processing

---

## Requirements
- React Native >= 0.81
- Expo >= 54
- react-native-vision-camera >= 4.x
- react-native-nitro-modules (for Nitro API)
- iOS >= 15.1, Android >= 26

> This plugin is built to be used as a **Vision Camera frame processor**. It does **NOT** process images from gallery or URLs via the frame-processor path — use the async Nitro API for that.

---

## Install (example)
```bash
npx expo install react-native-vision-camera
npm install react-native-camera-vision-pixel-colors
```

Add to `app.json` (or `app.config.js`) plugins:
```json
{
  "expo": {
    "plugins": [
      "react-native-vision-camera",
      "react-native-camera-vision-pixel-colors"
    ]
  }
}
```

Then:
```bash
npx expo prebuild
eas build -p ios
eas build -p android
```

---

## Usage

### Basic Frame Processor
```ts
import { useFrameProcessor } from 'react-native-vision-camera';
import { analyzePixelColors, type PixelColorsResult } from 'react-native-camera-vision-pixel-colors';

const frameProcessor = useFrameProcessor((frame) => {
  'worklet';
  const result: PixelColorsResult = analyzePixelColors(frame);
  // result => { uniqueColorCount, topColors: [{r,g,b}], brightestColors: [{r,g,b}] }
  console.log(result);
}, []);
```

Attach to `<Camera />` as `frameProcessor`.

### Advanced Options

Pass optional analysis options to enable additional features:

```ts
import { useFrameProcessor } from 'react-native-vision-camera';
import { analyzePixelColors, type AnalysisOptions } from 'react-native-camera-vision-pixel-colors';

const frameProcessor = useFrameProcessor((frame) => {
  'worklet';
  const options: AnalysisOptions = {
    // Analyze only center 20% of frame
    roi: { x: 0.4, y: 0.4, width: 0.2, height: 0.2 },

    // Enable motion detection
    enableMotionDetection: true,
    motionThreshold: 0.1, // 0-1, default: 0.1
  };

  const result = analyzePixelColors(frame, options);

  if (result.motion?.hasMotion) {
    console.log('Motion detected!', result.motion.score);
  }
}, []);
```

### Async Nitro API (outside camera)
```ts
import { CameraVisionPixelColors, type ImageData } from 'react-native-camera-vision-pixel-colors';

const imageData: ImageData = { width, height, data: arrayBuffer }; // data: ArrayBuffer (RGBA)
const result = await CameraVisionPixelColors.analyzeImageAsync(imageData);
```

---

## Output format

All types are exported from the library:
```ts
import {
  type RGBColor,
  type PixelColorsResult,
  type ImageData,
  type AnalysisOptions,
  type ROIConfig,
  type MotionResult,
} from 'react-native-camera-vision-pixel-colors';
```

```ts
type RGBColor = { r: number; g: number; b: number };

type ROIConfig = {
  x: number;      // 0-1 normalized
  y: number;      // 0-1 normalized
  width: number;  // 0-1 normalized
  height: number; // 0-1 normalized
};

type AnalysisOptions = {
  enableMotionDetection?: boolean; // default: false
  motionThreshold?: number;        // default: 0.1
  roi?: ROIConfig;                 // if provided, analyze only this region
};

type MotionResult = {
  score: number;      // 0-1
  hasMotion: boolean; // score > threshold
};

type PixelColorsResult = {
  uniqueColorCount: number;
  topColors: RGBColor[];
  brightestColors: RGBColor[];
  motion?: MotionResult;     // always present if enableMotionDetection=true
  roiApplied?: boolean;      // true if ROI config was provided
};

type ImageData = {
  width: number;
  height: number;
  data: ArrayBuffer; // RGBA pixel data
};
```

---

## Architecture summary
- Frame Processor path: **synchronous**, returns the latest cached result (0–1 frame latency).
- Async Nitro API: full GPU/CPU pipeline, returns an up-to-date result (Promise-based).
- Shared native engine (iOS/Android) exposes `analyzeAsync(...)` and `analyzeSync()` for the frame-processor path to read cached results.

### Memory & Performance Notes
- **Motion detection**: Uses grayscale comparison with configurable threshold
- **ROI**: Crops before analysis for improved performance on smaller regions
- **First frame motion**: Returns `{score: 0, hasMotion: false}` (not null)

---

## Contributing
PRs welcome. Please keep performance constraints in mind (avoid allocations per frame, reuse buffers).

---

## License
MIT © 2026
