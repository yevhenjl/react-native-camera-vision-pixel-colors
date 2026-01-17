const { withPlugins } = require('@expo/config-plugins');
const withPixelColorsIOS = require('./withPixelColorsIOS');
const withPixelColorsAndroid = require('./withPixelColorsAndroid');

const withPixelColors = (config) => {
  return withPlugins(config, [
    withPixelColorsIOS,
    withPixelColorsAndroid,
  ]);
};

module.exports = withPixelColors;
