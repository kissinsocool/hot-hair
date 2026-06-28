# csp_amap_flutter_location

[![pub package](https://img.shields.io/pub/v/csp_amap_flutter_location.svg)](https://pub.dev/packages/csp_amap_flutter_location)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios%20%7C%20harmonyos-lightgrey.svg)](https://pub.dev/packages/csp_amap_flutter_location)
[![License](https://img.shields.io/github/license/chenshipeng0914/csp_amap_flutter_location.svg)](https://gitee.com/chenshipeng0914/csp_amap_flutter_location/blob/master/LICENSE)

一个功能强大的Flutter高德地图定位插件，支持Android、iOS和鸿蒙平台。

[English](README.md) | **中文**

## 特性

- ✅ **多平台支持**: Android、iOS和鸿蒙平台
- ✅ **高精度定位**: 基于高德地图定位SDK
- ✅ **丰富配置**: 多种定位模式和参数配置
- ✅ **实时更新**: 基于Stream的定位监听
- ✅ **地址信息**: 逆地理编码支持
- ✅ **隐私合规**: 内置隐私政策管理
- ✅ **简易集成**: 简洁的API设计

## 安装

在 `pubspec.yaml` 文件中添加依赖：

```yaml
dependencies:
  csp_amap_flutter_location: ^1.0.2
```

然后运行：

```bash
flutter pub get
```

## 配置

### 1. 获取API密钥

首先，您需要从[高德开放平台](https://lbs.amap.com/)获取API密钥：

- [Android API密钥指南](https://lbs.amap.com/api/android-location-sdk/guide/create-project/get-key/)
- [iOS API密钥指南](https://lbs.amap.com/api/ios-location-sdk/guide/create-project/get-key)
- [鸿蒙API密钥指南](https://lbs.amap.com/api/harmonyosnext-location-sdk/guide/permission-description)

### 2. 平台配置

#### Android

在 `android/app/src/main/AndroidManifest.xml` 中添加以下权限：

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

在 `ios/Runner/Info.plist` 中添加定位权限：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>此应用需要访问位置信息以提供基于位置的服务。</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>此应用需要访问位置信息以提供基于位置的服务。</string>
```

#### 鸿蒙

详细配置请参考[鸿蒙定位SDK指南](https://lbs.amap.com/api/harmonyosnext-location-sdk/guide/permission-description)。

## 快速开始

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
    
    // 设置隐私政策（中国法律要求）
    AMapFlutterLocation.updatePrivacyShow(true, true);
    AMapFlutterLocation.updatePrivacyAgree(true);
    
    // 设置API密钥
    AMapFlutterLocation.setApiKey(
      "您的Android密钥", 
      "您的iOS密钥",
      ohosKey: "您的鸿蒙密钥" // 可选
    );
    
    // 监听定位更新
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
    // 配置定位选项
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
          title: Text('高德定位示例'),
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
                    child: Text('开始定位'),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _stopLocation,
                    child: Text('停止定位'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                '定位结果：',
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

## API参考

### AMapFlutterLocation

#### 静态方法

| 方法 | 描述 |
|------|------|
| `setApiKey(String androidKey, String iosKey, {String? ohosKey})` | 为不同平台设置API密钥 |
| `updatePrivacyShow(bool hasShow, bool hasContains)` | 更新隐私政策显示状态 |
| `updatePrivacyAgree(bool hasAgree)` | 更新隐私政策同意状态 |

#### 实例方法

| 方法 | 描述 |
|------|------|
| `setLocationOption(AMapLocationOption option)` | 配置定位参数 |
| `startLocation()` | 开始定位更新 |
| `stopLocation()` | 停止定位更新 |
| `destroy()` | 销毁定位服务 |
| `onLocationChanged()` | 监听定位变化（返回Stream） |

### AMapLocationOption

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `needAddress` | `bool` | `true` | 是否返回地址信息 |
| `geoLanguage` | `GeoLanguage` | `DEFAULT` | 逆地理编码语言 |
| `onceLocation` | `bool` | `false` | 是否只定位一次 |
| `locationMode` | `AMapLocationMode` | `Hight_Accuracy` | 定位模式（仅Android） |
| `locationInterval` | `int` | `2000` | 定位更新间隔，毫秒（仅Android） |
| `desiredAccuracy` | `DesiredAccuracy` | `Best` | 期望精度（仅iOS） |
| `distanceFilter` | `double` | `-1` | 最小更新距离，米（仅iOS） |

### 定位结果

定位结果以 `Map<String, Object>` 形式返回，包含以下键：

| 键 | 类型 | 描述 |
|----|------|------|
| `latitude` | `double` | 纬度 |
| `longitude` | `double` | 经度 |
| `accuracy` | `double` | 定位精度，米 |
| `altitude` | `double` | 海拔，米 |
| `bearing` | `double` | 方位角，度 |
| `speed` | `double` | 速度，米/秒 |
| `locationTime` | `String` | 定位时间戳 |
| `address` | `String` | 格式化地址 |
| `country` | `String` | 国家 |
| `province` | `String` | 省/州 |
| `city` | `String` | 城市 |
| `district` | `String` | 区/县 |
| `street` | `String` | 街道 |
| `streetNumber` | `String` | 门牌号 |
| `cityCode` | `String` | 城市代码 |
| `adCode` | `String` | 行政区划代码 |
| `errorCode` | `String` | 错误代码（定位失败时） |
| `errorInfo` | `String` | 错误信息（定位失败时） |

## 高级用法

### 单次定位

```dart
AMapLocationOption option = AMapLocationOption();
option.onceLocation = true;
_locationPlugin.setLocationOption(option);
_locationPlugin.startLocation();
```

### 高精度定位

```dart
AMapLocationOption option = AMapLocationOption();
option.locationMode = AMapLocationMode.Hight_Accuracy;
option.desiredAccuracy = DesiredAccuracy.Best;
_locationPlugin.setLocationOption(option);
```

### 自定义更新间隔

```dart
AMapLocationOption option = AMapLocationOption();
option.locationInterval = 5000; // 5秒
_locationPlugin.setLocationOption(option);
```

## 故障排除

### Android依赖问题

如果在Android上遇到`NoClassDefFoundError`或`ClassNotFoundException`错误：

``log
java.lang.NoClassDefFoundError: Failed resolution of: Lcom/amap/api/location/AMapLocationClient;
```

这是由于依赖配置不正确导致的。插件已经修复，将高德地图SDK依赖从`compileOnly`改为`api`，确保运行时可用：

```gradle
dependencies {
    api 'com.amap.api:location:6.4.9'
}
```

### iOS Podfile问题

如果在iOS上遇到Podfile错误：

```bash
rm ios/Podfile
flutter build ios
```

### 权限问题

确保您已经：
1. 在平台清单中添加了必要的权限
2. 在应用中请求了运行时权限
3. 设置了隐私政策合规（中国应用）

### API密钥问题

1. 验证您的API密钥是否正确
2. 检查Bundle ID/包名是否与高德控制台中的一致
3. 确保您的API密钥启用了所需的权限

## 贡献

欢迎贡献！请随时提交Pull Request。

## 许可证

本项目基于MIT许可证 - 详情请参阅[LICENSE](LICENSE)文件。

## 支持

如果您有任何问题或疑问，请：

1. 查看[文档](https://lbs.amap.com/)
2. 搜索现有的[问题](https://gitee.com/chenshipeng0914/csp_amap_flutter_location/issues)
3. 如需要，创建新的问题

## 更新日志

详见[CHANGELOG.md](CHANGELOG.md)了解各版本的变更详情。