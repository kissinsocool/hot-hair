/// 定位参数设置
/// 用于配置高德定位SDK的各项参数
class AMapLocationOption {
  /// 是否需要地址信息，默认true
  /// 设置为true时会返回地址信息，false则不返回
  bool needAddress = true;

  /// 是否需要开启locatingWithReGeocode
  /// 设置为true时会进行逆地理编码，获取地址信息
  bool locatingWithReGeocode = false;

  /// 是否允许后台定位更新
  bool allowsBackgroundLocationUpdates = false;

  /// 逆地理信息语言类型
  /// 默认[GeoLanguage.DEFAULT] 自动适配
  /// 可选值：
  /// [GeoLanguage.DEFAULT] 自动适配
  /// [GeoLanguage.EN] 英文
  /// [GeoLanguage.ZH] 中文
  GeoLanguage geoLanguage;

  /// 是否单次定位
  /// 默认值：false（连续定位）
  /// 设置为true时只定位一次，false为连续定位
  bool onceLocation = false;

  /// Android端定位模式, 只在Android系统上有效
  /// 默认值：[AMapLocationMode.Hight_Accuracy]
  /// 可选值：
  /// [AMapLocationMode.Battery_Saving] 低功耗模式
  /// [AMapLocationMode.Device_Sensors] 仅设备模式
  /// [AMapLocationMode.Hight_Accuracy] 高精度模式
  AMapLocationMode locationMode;

  /// Android端定位间隔
  /// 单位：毫秒
  /// 默认：2000毫秒
  /// 只在连续定位模式下有效
  int locationInterval = 2000;

  /// iOS端是否允许系统暂停定位
  /// 默认：false
  /// 设置为true时，当APP进入后台时，定位会被系统暂停
  bool pausesLocationUpdatesAutomatically = false;

  /// iOS端期望的定位精度，只在iOS端有效
  /// 默认值：最高精度
  /// 可选值：
  /// [DesiredAccuracy.Best] 最高精度
  /// [DesiredAccuracy.BestForNavigation] 适用于导航场景的高精度
  /// [DesiredAccuracy.NearestTenMeters] 10米
  /// [DesiredAccuracy.Kilometer] 1000米
  /// [DesiredAccuracy.ThreeKilometers] 3000米
  DesiredAccuracy desiredAccuracy = DesiredAccuracy.Best;

  /// iOS端定位最小更新距离
  /// 单位：米
  /// 默认值：-1，不做限制
  /// 设置为正数时，只有移动距离超过这个值才会更新位置
  double distanceFilter = -1;

  /// iOS 14中设置期望的定位精度权限
  /// 控制请求的定位精度权限类型
  AMapLocationAccuracyAuthorizationMode
      desiredLocationAccuracyAuthorizationMode =
      AMapLocationAccuracyAuthorizationMode.FullAccuracy;

  /// iOS 14中定位精度权限由模糊定位升级到精确定位时，需要用到的场景key
  /// fullAccuracyPurposeKey 这个key要和plist中的配置一样
  String fullAccuracyPurposeKey = "";

  /// 构造函数
  /// 创建定位参数对象，可以设置各种定位参数
  AMapLocationOption(
      {this.locationInterval = 2000,
      this.needAddress = true,
      this.locatingWithReGeocode = false,
      this.locationMode = AMapLocationMode.Hight_Accuracy,
      this.geoLanguage = GeoLanguage.DEFAULT,
      this.onceLocation = false,
      this.pausesLocationUpdatesAutomatically = false,
      this.desiredAccuracy = DesiredAccuracy.Best,
      this.distanceFilter = -1,
      this.desiredLocationAccuracyAuthorizationMode =
          AMapLocationAccuracyAuthorizationMode.FullAccuracy});

  /// 获取设置的定位参数对应的Map
  /// 将所有参数转换为Map格式，用于传递给原生平台
  /// 返回：包含所有定位参数的Map对象
  Map getOptionsMap() {
    return {
      "locationInterval": locationInterval,
      "needAddress": needAddress,
      "locatingWithReGeocode": locatingWithReGeocode,
      "locationMode": locationMode.index,
      "geoLanguage": geoLanguage.index,
      "onceLocation": onceLocation,
      "pausesLocationUpdatesAutomatically": pausesLocationUpdatesAutomatically,
      "desiredAccuracy": desiredAccuracy.index,
      'distanceFilter': distanceFilter,
      "locationAccuracyAuthorizationMode":
          desiredLocationAccuracyAuthorizationMode.index,
      "fullAccuracyPurposeKey": fullAccuracyPurposeKey
    };
  }
}

/// Android端定位模式
/// 用于设置Android设备的定位模式
enum AMapLocationMode {
  /// 低功耗模式
  /// 优先使用网络定位，准确度较差但耗电量低
  Battery_Saving,

  /// 仅设备模式,不支持室内环境的定位
  /// 只使用GPS进行定位，在室外准确度高，但耗电量大
  Device_Sensors,

  /// 高精度模式
  /// 同时使用网络和GPS定位，准确度高但耗电量也大
  Hight_Accuracy
}

/// 逆地理信息语言
/// 设置返回的地址信息的语言类型
enum GeoLanguage {
  /// 默认，自动适配
  /// 根据系统语言自动选择返回中文或英文
  DEFAULT,

  /// 汉语，无论在国内还是国外都返回中文
  ZH,

  /// 英语，无论在国内还是国外都返回英文
  EN
}

/// iOS中期望的定位精度
/// 控制iOS设备的定位精度，精度越高越耗电
enum DesiredAccuracy {
  /// 最高精度
  /// 最准确的位置信息，但耗电量最大
  Best,

  /// 适用于导航场景的高精度
  /// 适合导航应用使用的高精度定位
  BestForNavigation,

  /// 10米
  /// 精确到10米范围内，适合大多数应用场景
  NearestTenMeters,

  /// 100米
  /// 精确到100米范围内
  HundredMeters,

  /// 1000米
  /// 精确到1公里范围内，耗电量较低
  Kilometer,

  /// 3000米
  /// 精确到3公里范围内，最省电
  ThreeKilometers,
}

/// iOS 14中期望的定位精度权限,只有在iOS 14的设备上才能生效
/// 控制iOS 14及以上系统的定位精度权限请求
enum AMapLocationAccuracyAuthorizationMode {
  /// 精确和模糊定位
  /// 同时请求精确和模糊定位权限
  FullAndReduceAccuracy,

  /// 精确定位
  /// 只请求精确定位权限
  FullAccuracy,

  /// 模糊定位
  /// 只请求模糊定位权限
  ReduceAccuracy
}

/// iOS 14中系统的定位类型信息
/// 表示iOS 14及以上系统当前授予的定位精度权限
enum AMapAccuracyAuthorization {
  /// 系统的精确定位类型
  /// 用户已授予精确定位权限
  AMapAccuracyAuthorizationFullAccuracy,

  /// 系统的模糊定位类型
  /// 用户只授予了模糊定位权限
  AMapAccuracyAuthorizationReducedAccuracy,

  /// 未知类型
  /// 权限状态未知或无法确定
  AMapAccuracyAuthorizationInvalid
}
