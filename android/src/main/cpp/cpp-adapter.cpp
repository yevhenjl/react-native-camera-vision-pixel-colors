#include <jni.h>
#include "CameraVisionPixelColorsOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return margelo::nitro::cameravisionpixelcolors::initialize(vm);
}
