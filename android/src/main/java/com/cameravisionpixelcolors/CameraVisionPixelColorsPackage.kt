package com.cameravisionpixelcolors;

import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.module.model.ReactModuleInfoProvider;
import com.facebook.react.TurboReactPackage;
import com.margelo.nitro.cameravisionpixelcolors.CameraVisionPixelColorsOnLoad;
import com.mrousavy.camera.frameprocessors.FrameProcessorPluginRegistry;


public class CameraVisionPixelColorsPackage : TurboReactPackage() {
  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? = null

  override fun getReactModuleInfoProvider(): ReactModuleInfoProvider = ReactModuleInfoProvider { emptyMap() }

  companion object {
    init {
      CameraVisionPixelColorsOnLoad.initializeNative();
      FrameProcessorPluginRegistry.addFrameProcessorPlugin("pixelColors") { proxy, options ->
        PixelColorsFrameProcessor(proxy, options)
      }
    }
  }
}
