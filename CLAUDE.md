# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

React Native native module library built with **Nitro Modules**. It's a Vision Camera Frame Processor plugin for real-time pixel color analysis on camera frames (iOS/Android).

## Common Commands

```bash
# Build (type-check + compile JS/TS via bob)
npm run build

# Run Nitro code generation after modifying specs
npm run codegen

# Type-check only
npm run typecheck

# Clean generated files
npm run clean
```

### Example App (in `example/`)

```bash
cd example
npm run ios              # Build & run on iOS simulator (iPhone 16)
npm run android          # Build & run on Android
npm run start            # Start Metro bundler
npm run pod              # Install iOS CocoaPods
npm run lint             # ESLint
npm run test             # Jest tests
```

## Architecture

### Key Files

| File | Purpose |
|------|---------|
| `src/specs/camera-vision-pixel-colors.nitro.ts` | TypeScript interface defining the Nitro HybridObject |
| `src/index.ts` | Main export, creates the Nitro hybrid object |
| `ios/HybridCameraVisionPixelColors.swift` | iOS native implementation |
| `android/.../HybridCameraVisionPixelColors.kt` | Android native implementation |
| `nitro.json` | Nitro module configuration |
| `nitrogen/generated/` | Auto-generated Nitro bindings (do not edit) |

### Development Workflow

1. Define/modify TypeScript interface in `src/specs/camera-vision-pixel-colors.nitro.ts`
2. Run `npm run codegen` to regenerate Nitro bindings
3. Implement native methods in Swift (`ios/`) and Kotlin (`android/src/`)
4. Test with example app

### Nitro Module Pattern

- Interface extends `HybridObject<{ ios: 'swift', android: 'kotlin' }>`
- Native implementations extend generated spec classes (`HybridCameraVisionPixelColorsSpec`)
- The `nitrogen/` directory is auto-generated; `post-script.js` applies Android-specific fixes

## Performance Constraints

Frame processor runs synchronously on native thread. Avoid:
- Per-frame allocations
- Heavy computations in sync path
- Large data transfers across bridge

Reuse buffers where possible.
