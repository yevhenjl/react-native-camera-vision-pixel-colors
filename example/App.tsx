import React, { useEffect, useState, useCallback } from 'react';
import {
  Alert,
  Text,
  View,
  StyleSheet,
  Pressable,
  Platform,
  Linking,
} from 'react-native';
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useFrameProcessor,
} from 'react-native-vision-camera';
import { useRunOnJS } from 'react-native-worklets-core';
import {
  analyzePixelColors,
  type PixelColorsResult,
} from 'react-native-camera-vision-pixel-colors';

function App(): React.JSX.Element {
  const device = useCameraDevice('back');
  const { hasPermission, requestPermission } = useCameraPermission();
  const [result, setResult] = useState<PixelColorsResult | null>(null);

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
  }, []);

  const updateResultJS = useRunOnJS(updateResult, [updateResult]);

  const frameProcessor = useFrameProcessor(
    frame => {
      'worklet';
      const colors = analyzePixelColors(frame);
      updateResultJS(colors);
    },
    [updateResultJS],
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
      <View style={styles.overlay}>
        <Text style={styles.title}>Pixel Colors Analysis</Text>
        {result && (
          <>
            <Text style={styles.text}>
              Unique Colors: {result.uniqueColorCount}
            </Text>
            <Text style={styles.label}>Top Colors:</Text>
            <View style={styles.colorRow}>
              {result.topColors.map((color, i) => (
                <View
                  key={i}
                  style={[
                    styles.colorBox,
                    {
                      backgroundColor: `rgb(${color.r}, ${color.g}, ${color.b})`,
                    },
                  ]}
                />
              ))}
            </View>
            <Text style={styles.label}>Brightest Colors:</Text>
            <View style={styles.colorRow}>
              {result.brightestColors.map((color, i) => (
                <View
                  key={i}
                  style={[
                    styles.colorBox,
                    {
                      backgroundColor: `rgb(${color.r}, ${color.g}, ${color.b})`,
                    },
                  ]}
                />
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
  colorRow: {
    flexDirection: 'row',
    gap: 8,
  },
  colorBox: {
    width: 50,
    height: 50,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#fff',
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
