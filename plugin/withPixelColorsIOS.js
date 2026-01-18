const { withInfoPlist } = require('@expo/config-plugins');

const withPixelColorsIOS = (config) => {
  return withInfoPlist(config, (config) => {
    // Camera usage description is handled by react-native-vision-camera plugin
    // This plugin is a pass-through for iOS as VisionCamera handles permissions
    return config;
  });
};

module.exports = withPixelColorsIOS;
