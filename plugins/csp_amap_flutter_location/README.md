# csp_amap_flutter_location

[![pub package](https://img.shields.io/pub/v/csp_amap_flutter_location.svg)](https://pub.dev/packages/csp_amap_flutter_location)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios%20%7C%20harmonyos-lightgrey.svg)](https://pub.dev/packages/csp_amap_flutter_location)
[![License](https://img.shields.io/github/license/chenshipeng0914/csp_amap_flutter_location.svg)](https://gitee.com/chenshipeng0914/csp_amap_flutter_location/blob/master/LICENSE)

一个功能强大的Flutter高德地图定位插件，支持Android、iOS和鸿蒙平台。

**English** | [中文](README_CN.md)

## Features

- ✅ **Multi-platform Support**: Android, iOS, and HarmonyOS
- ✅ **High Precision**: Powered by AMap Location SDK
- ✅ **Rich Configuration**: Multiple location modes and parameters
- ✅ **Real-time Updates**: Stream-based location listening
- ✅ **Address Information**: Reverse geocoding support
- ✅ **Privacy Compliant**: Built-in privacy policy management
- ✅ **Easy Integration**: Simple API design

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  csp_amap_flutter_location: ^1.0.2
```

Then run:

```bash
flutter pub get
```

## Setup

### 1. Get API Keys

First, you need to obtain API keys from [AMap Open Platform](https://lbs.amap.com/):

- [Android API Key Guide](https://lbs.amap.com/api/android-location-sdk/guide/create-project/get-key/)
- [iOS API Key Guide](https://lbs.amap.com/api/ios-location-sdk/guide/create-project/get-key)
- [HarmonyOS API Key Guide](https://lbs.amap.com/api/harmonyosnext-location-sdk/guide/permission-description)

### 2. Platform Configuration

#### Android

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
```

#### iOS

Add location permissions to your `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to provide location-based services.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to provide location-based services.</string>
```

#### HarmonyOS

Refer to [HarmonyOS Location SDK Guide](https://lbs.amap.com/api/harmonyosnext-location-sdk/guide/permission-description) for detailed setup.

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:csp_amap_flutter_location/amap_flutter_location.dart';
import 'package:csp_amap_flutter_location/amap_location_option.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AMapFlutterLocation _locationPlugin;
  Map<String, Object>? _locationResult;

  @override
  void initState() {
    super.initState();
    
    _locationPlugin = AMapFlutterLocation();
    
    // Set privacy policy (required by Chinese law)
    AMapFlutterLocation.updatePrivacyShow(true, true);
    AMapFlutterLocation.updatePrivacyAgree(true);
    
    // Set API keys
    AMapFlutterLocation.setApiKey(
      "YOUR_ANDROID_KEY", 
      "YOUR_IOS_KEY",
      ohosKey: "YOUR_HARMONYOS_KEY" // Optional
    );
    
    // Listen to location updates
    _locationPlugin.onLocationChanged().listen((Map<String, Object> result) {
      setState(() {
        _locationResult = result;
      });
    });
  }

  @override
  void dispose() {
    _locationPlugin.destroy();
    super.dispose();
  }

  void _startLocation() {
    // Configure location options
    AMapLocationOption locationOption = AMapLocationOption();
    locationOption.onceLocation = false;
    locationOption.needAddress = true;
    locationOption.geoLanguage = GeoLanguage.DEFAULT;
    
    _locationPlugin.setLocationOption(locationOption);
    _locationPlugin.startLocation();
  }

  void _stopLocation() {
    _locationPlugin.stopLocation();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('AMap Location Demo'),
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _startLocation,
                    child: Text('Start Location'),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _stopLocation,
                    child: Text('Stop Location'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'Location Result:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              if (_locationResult != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      _formatLocationResult(_locationResult!),
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLocationResult(Map<String, Object> result) {
    StringBuffer buffer = StringBuffer();
    result.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    return buffer.toString();
  }
}
```

## API Reference

### AMapFlutterLocation

#### Static Methods

| Method | Description |
|--------|-------------|
| `setApiKey(String androidKey, String iosKey, {String? ohosKey})` | Set API keys for different platforms |
| `updatePrivacyShow(bool hasShow, bool hasContains)` | Update privacy policy display status |
| `updatePrivacyAgree(bool hasAgree)` | Update privacy policy agreement status |

#### Instance Methods

| Method | Description |
|--------|-------------|
| `setLocationOption(AMapLocationOption option)` | Configure location parameters |
| `startLocation()` | Start location updates |
| `stopLocation()` | Stop location updates |
| `destroy()` | Destroy the location service |
| `onLocationChanged()` | Listen to location changes (returns Stream) |

### AMapLocationOption

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `needAddress` | `bool` | `true` | Whether to return address information |
| `geoLanguage` | `GeoLanguage` | `DEFAULT` | Language for reverse geocoding |
| `onceLocation` | `bool` | `false` | Whether to locate only once |
| `locationMode` | `AMapLocationMode` | `Hight_Accuracy` | Location mode (Android only) |
| `locationInterval` | `int` | `2000` | Location update interval in milliseconds (Android only) |
| `desiredAccuracy` | `DesiredAccuracy` | `Best` | Desired accuracy (iOS only) |
| `distanceFilter` | `double` | `-1` | Minimum distance for updates in meters (iOS only) |

### Location Result

The location result is returned as a `Map<String, Object>` with the following keys:

| Key | Type | Description |
|-----|------|-------------|
| `latitude` | `double` | Latitude |
| `longitude` | `double` | Longitude |
| `accuracy` | `double` | Location accuracy in meters |
| `altitude` | `double` | Altitude in meters |
| `bearing` | `double` | Bearing in degrees |
| `speed` | `double` | Speed in m/s |
| `locationTime` | `String` | Location timestamp |
| `address` | `String` | Formatted address |
| `country` | `String` | Country |
| `province` | `String` | Province/State |
| `city` | `String` | City |
| `district` | `String` | District |
| `street` | `String` | Street |
| `streetNumber` | `String` | Street number |
| `cityCode` | `String` | City code |
| `adCode` | `String` | Administrative division code |
| `errorCode` | `String` | Error code (when location fails) |
| `errorInfo` | `String` | Error message (when location fails) |

## Advanced Usage

### Single Location

```dart
AMapLocationOption option = AMapLocationOption();
option.onceLocation = true;
_locationPlugin.setLocationOption(option);
_locationPlugin.startLocation();
```

### High-Precision Location

```dart
AMapLocationOption option = AMapLocationOption();
option.locationMode = AMapLocationMode.Hight_Accuracy;
option.desiredAccuracy = DesiredAccuracy.Best;
_locationPlugin.setLocationOption(option);
```

### Custom Update Interval

```dart
AMapLocationOption option = AMapLocationOption();
option.locationInterval = 5000; // 5 seconds
_locationPlugin.setLocationOption(option);
```

## Troubleshooting

### Android Dependency Issues

If you encounter `NoClassDefFoundError` or `ClassNotFoundException` on Android:

```
java.lang.NoClassDefFoundError: Failed resolution of: Lcom/amap/api/location/AMapLocationClient;
```

This is caused by incorrect dependency configuration. The plugin has been fixed to use `api` instead of `compileOnly` for the AMap SDK dependency:

```
dependencies {
    api 'com.amap.api:location:6.4.9'
}
```

### iOS Podfile Issues

If you encounter Podfile errors on iOS:

```bash
rm ios/Podfile
flutter build ios
```

### Permission Issues

Make sure you have:
1. Added required permissions to platform manifests
2. Requested runtime permissions in your app
3. Set up privacy policy compliance (for Chinese apps)

### API Key Issues

1. Verify your API keys are correct
2. Check if your bundle ID/package name matches the one in AMap console
3. Ensure your API keys have the required permissions enabled

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you have any questions or issues, please:

1. Check the [documentation](https://lbs.amap.com/)
2. Search existing [issues](https://gitee.com/chenshipeng0914/csp_amap_flutter_location/issues)
3. Create a new issue if needed

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for details about changes in each version.