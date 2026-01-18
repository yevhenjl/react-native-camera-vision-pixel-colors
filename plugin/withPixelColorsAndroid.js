const { withAndroidManifest } = require('@expo/config-plugins');

const withPixelColorsAndroid = (config) => {
  return withAndroidManifest(config, (config) => {
    // Camera permission is handled by react-native-vision-camera plugin
    // This plugin is a pass-through for Android as VisionCamera handles permissions
    return config;
  });
};

module.exports = withPixelColorsAndroid;
