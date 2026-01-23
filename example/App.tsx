import React, { useEffect, useState, useCallback } from 'react';
import {
  Alert,
  Text,
  View,
  StyleSheet,
  Pressable,
  Platform,
  Linking,
  Switch,
} from 'react-native';
import Slider from '@react-native-community/slider';
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useFrameProcessor,
} from 'react-native-vision-camera';
import { useRunOnJS, useSharedValue } from 'react-native-worklets-core';
import {
  analyzePixelColors,
  type PixelColorsResult,
  type AnalysisOptions,
} from 'react-native-camera-vision-pixel-colors';

function App(): React.JSX.Element {
  const device = useCameraDevice('back');
  const { hasPermission, requestPermission } = useCameraPermission();
  const [result, setResult] = useState<PixelColorsResult | null>(null);

  // Feature toggles
  const [enableMotion, setEnableMotion] = useState(false);
  const [enableROI, setEnableROI] = useState(false);
  const [enableHsv, setEnableHsv] = useState(false);
  const [enableThreshold, setEnableThreshold] = useState(false);
  const [maxTopColors, setMaxTopColors] = useState(3);
  const [maxBrightestColors, setMaxBrightestColors] = useState(3);

  // Shared values for worklet access
  const motionEnabled = useSharedValue(false);
  const roiEnabled = useSharedValue(false);
  const hsvEnabled = useSharedValue(false);
  const thresholdEnabled = useSharedValue(false);
  const topColorsCount = useSharedValue(3);
  const brightestColorsCount = useSharedValue(3);

  useEffect(() => {
    motionEnabled.value = enableMotion;
  }, [enableMotion, motionEnabled]);

  useEffect(() => {
    roiEnabled.value = enableROI;
  }, [enableROI, roiEnabled]);

  useEffect(() => {
    hsvEnabled.value = enableHsv;
  }, [enableHsv, hsvEnabled]);

  useEffect(() => {
    thresholdEnabled.value = enableThreshold;
  }, [enableThreshold, thresholdEnabled]);

  useEffect(() => {
    topColorsCount.value = maxTopColors;
  }, [maxTopColors, topColorsCount]);

  useEffect(() => {
    brightestColorsCount.value = maxBrightestColors;
  }, [maxBrightestColors, brightestColorsCount]);

  useEffect(() => {
    if (!hasPermission) {
      requestPermission();
    }
  }, [hasPermission, requestPermission]);

  const updateResult = useCallback((newResult: PixelColorsResult) => {
    setResult(newResult);
  }, []);

  const handlePermission = useCallback(async () => {
    const granted = await requestPermission();

    if (!granted) {
      Alert.alert(
        'Camera Permission Required',
        'Please grant camera access to use the light detector.',
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Open Settings', onPress: () => Linking.openSettings() },
        ],
      );
      return;
    }
  }, [requestPermission]);

  const updateResultJS = useRunOnJS(updateResult, [updateResult]);

  const frameProcessor = useFrameProcessor(
    frame => {
      'worklet';
      const options: AnalysisOptions = {
        maxTopColors: topColorsCount.value,
        maxBrightestColors: brightestColorsCount.value,
      };

      if (motionEnabled.value) {
        options.enableMotionDetection = true;
        options.motionThreshold = 0.1;
      }

      if (roiEnabled.value) {
        options.roi = { x: 0.35, y: 0.35, width: 0.3, height: 0.3 };
      }

      if (hsvEnabled.value) {
        options.enableHsvAnalysis = true;
      }

      if (thresholdEnabled.value) {
        options.minPixelThreshold = 0.002; // 0.2%
      }

      const colors = analyzePixelColors(frame, options);
      updateResultJS(colors);
    },
    [updateResultJS, motionEnabled, roiEnabled, hsvEnabled, thresholdEnabled, topColorsCount, brightestColorsCount],
  );

  const openSettings = useCallback(() => {
    if (Platform.OS === 'ios') {
      Linking.openURL('app-settings:');
    } else {
      Linking.openSettings();
    }
  }, []);

  if (!hasPermission) {
    return (
      <View style={styles.container}>
        <Text style={styles.text}>Camera permission required</Text>
        <Pressable style={styles.button} onPress={handlePermission}>
          <Text style={styles.buttonText}>Grant Permission</Text>
        </Pressable>
        <Pressable style={styles.button} onPress={openSettings}>
          <Text style={styles.buttonText}>Open Settings</Text>
        </Pressable>
      </View>
    );
  }

  if (!device) {
    return (
      <View style={styles.container}>
        <Text style={styles.text}>No camera device available</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Camera
        style={StyleSheet.absoluteFill}
        device={device}
        isActive={true}
        frameProcessor={frameProcessor}
      />

      {/* ROI overlay indicator */}
      {enableROI && (
        <View style={styles.roiOverlay}>
          <View style={styles.roiBox} />
        </View>
      )}

      {/* Feature toggles */}
      <View style={styles.toggleContainer}>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>Motion Detection</Text>
          <Switch value={enableMotion} onValueChange={setEnableMotion} />
        </View>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>ROI (Center 30%)</Text>
          <Switch value={enableROI} onValueChange={setEnableROI} />
        </View>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>HSV Analysis</Text>
          <Switch value={enableHsv} onValueChange={setEnableHsv} />
        </View>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>Pixel Threshold (0.2%)</Text>
          <Switch value={enableThreshold} onValueChange={setEnableThreshold} />
        </View>
        <View style={styles.sliderRow}>
          <Text style={styles.toggleLabel}>Top Colors: {maxTopColors}</Text>
          <Slider
            style={styles.slider}
            minimumValue={1}
            maximumValue={10}
            step={1}
            value={maxTopColors}
            onValueChange={setMaxTopColors}
            minimumTrackTintColor="#007AFF"
            maximumTrackTintColor="#666"
            thumbTintColor="#007AFF"
          />
        </View>
        <View style={styles.sliderRow}>
          <Text style={styles.toggleLabel}>Brightest Colors: {maxBrightestColors}</Text>
          <Slider
            style={styles.slider}
            minimumValue={1}
            maximumValue={10}
            step={1}
            value={maxBrightestColors}
            onValueChange={setMaxBrightestColors}
            minimumTrackTintColor="#007AFF"
            maximumTrackTintColor="#666"
            thumbTintColor="#007AFF"
          />
        </View>
      </View>

      <View style={styles.overlay}>
        <Text style={styles.title}>Pixel Colors Analysis</Text>
        {result && (
          <>
            <Text style={styles.text}>
              Unique Colors: {result.uniqueColorCount}
            </Text>

            {result.roiApplied && (
              <Text style={styles.featureTag}>ROI Applied</Text>
            )}

            {result.motion && (
              <View style={styles.motionContainer}>
                <Text style={styles.label}>Motion:</Text>
                <View style={styles.motionRow}>
                  <View
                    style={[
                      styles.motionIndicator,
                      {
                        backgroundColor: result.motion.hasMotion
                          ? '#FF4444'
                          : '#44FF44',
                      },
                    ]}
                  />
                  <Text style={styles.text}>
                    Score: {(result.motion.score * 100).toFixed(1)}%
                  </Text>
                </View>
              </View>
            )}

            {result.totalPixelsAnalyzed !== undefined && (
              <Text style={styles.featureTag}>
                Total Pixels: {result.totalPixelsAnalyzed.toLocaleString()}
              </Text>
            )}

            <Text style={styles.label}>Top Colors:</Text>
            <View style={styles.colorRow}>
              {result.topColors.map((color, i) => (
                <View key={i} style={styles.colorItem}>
                  <View
                    style={[
                      styles.colorBox,
                      {
                        backgroundColor: `rgb(${color.r}, ${color.g}, ${color.b})`,
                      },
                    ]}
                  />
                  {color.hsv && (
                    <Text style={styles.hsvText}>
                      H:{Math.round(color.hsv.h)}
                    </Text>
                  )}
                  {color.pixelPercentage !== undefined && (
                    <Text style={styles.percentText}>
                      {(color.pixelPercentage * 100).toFixed(1)}%
                    </Text>
                  )}
                </View>
              ))}
            </View>
            <Text style={styles.label}>Brightest Colors:</Text>
            <View style={styles.colorRow}>
              {result.brightestColors.map((color, i) => (
                <View key={i} style={styles.colorItem}>
                  <View
                    style={[
                      styles.colorBox,
                      {
                        backgroundColor: `rgb(${color.r}, ${color.g}, ${color.b})`,
                      },
                    ]}
                  />
                  {color.hsv && (
                    <Text style={styles.hsvText}>
                      H:{Math.round(color.hsv.h)}
                    </Text>
                  )}
                  {color.pixelPercentage !== undefined && (
                    <Text style={styles.percentText}>
                      {(color.pixelPercentage * 100).toFixed(1)}%
                    </Text>
                  )}
                </View>
              ))}
            </View>
          </>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#000',
  },
  overlay: {
    position: 'absolute',
    bottom: 50,
    left: 20,
    right: 20,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    borderRadius: 12,
    padding: 16,
  },
  toggleContainer: {
    position: 'absolute',
    top: 60,
    left: 20,
    right: 20,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    borderRadius: 12,
    padding: 12,
  },
  toggleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 6,
  },
  toggleLabel: {
    color: '#fff',
    fontSize: 14,
  },
  sliderRow: {
    paddingVertical: 6,
  },
  slider: {
    width: '100%',
    height: 30,
  },
  roiOverlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
  },
  roiBox: {
    width: '30%',
    height: '30%',
    borderWidth: 2,
    borderColor: '#00FF00',
    borderStyle: 'dashed',
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 12,
  },
  text: {
    fontSize: 16,
    color: '#fff',
    marginBottom: 8,
  },
  label: {
    fontSize: 14,
    color: '#aaa',
    marginTop: 8,
    marginBottom: 4,
  },
  featureTag: {
    fontSize: 12,
    color: '#00FF00',
    marginBottom: 4,
  },
  motionContainer: {
    marginTop: 8,
  },
  motionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  motionIndicator: {
    width: 16,
    height: 16,
    borderRadius: 8,
  },
  colorRow: {
    flexDirection: 'row',
    gap: 8,
    flexWrap: 'wrap',
  },
  colorItem: {
    alignItems: 'center',
  },
  colorBox: {
    width: 50,
    height: 50,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#fff',
  },
  hsvText: {
    fontSize: 10,
    color: '#aaa',
    marginTop: 2,
  },
  percentText: {
    fontSize: 10,
    color: '#00FF00',
  },
  button: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
    marginTop: 12,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});

export default App;
