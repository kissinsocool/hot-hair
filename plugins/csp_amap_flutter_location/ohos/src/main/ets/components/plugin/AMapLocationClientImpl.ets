import {
  AMapLocationManagerImpl,
  AMapLocationOption,
  AMapLocationReGeocodeLanguage,
  AMapLocationType,
  IAMapLocationListener,
} from '@amap/amap_lbs_location';
import { EventSink } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import geoLocationManager from '@ohos.geoLocationManager';
import { Context } from '@ohos.arkui.UIContext';
import { Any } from '@ohos/flutter_ohos';

/**
 * 高德地图定位客户端实现类
 * 封装了高德地图定位SDK的功能，支持单次定位和连续定位
 */
export default class AMapLocationClientImpl {
  // 高德定位管理器实例
  private locationManager: AMapLocationManagerImpl | undefined;
  // 应用上下文
  private context: Context;
  // 定位选项
  private options: AMapLocationOption = {};
  // 事件接收器，用于向Flutter端发送定位结果
  private eventSink?: EventSink;
  // 插件实例的唯一标识符
  private pluginKey: string;
  // 是否需要地址信息
  private isNeedAddress: boolean = false;
  // 是否是单次定位
  private onceLocation: boolean = true;
  // 日志标签
  private TAG = "AMapLocationClientImpl";
  // 定位监听器
  private locationListener?: IAMapLocationListener;

  /**
   * 构造函数
   * @param context 应用上下文
   * @param pluginKey 插件唯一标识符
   * @param eventSink 事件接收器
   */
  constructor(context: Context, pluginKey: string, eventSink?: EventSink) {
    this.context = context;
    this.pluginKey = pluginKey;
    this.eventSink = eventSink;
    // 初始化定位管理器
    this.locationManager = new AMapLocationManagerImpl(context);
  }

  /**
   * 设置定位参数
   * @param map 定位参数映射
   */
  setLocationOption(map: Any) {
    let tempMap:Map<string,Any> = map as Map<string,Any>
    console.info(this.TAG + ' setLocationOption: ' + JSON.stringify(tempMap));

    // 配置定位选项
    this.options = {
      priority: geoLocationManager.LocationRequestPriority.FIRST_FIX, // 优先获取第一次定位结果
      scenario: geoLocationManager.LocationRequestScenario.UNSET, // 未设置场景
      maxAccuracy: 0, // 最大精度
      timeInterval: 2, // 定位间隔
      distanceInterval: 0, // 定位精度 单位：米
      singleLocationTimeout: 3000, // 单次定位超时时间
      allowsBackgroundLocationUpdates: false, // 是否允许后台定位
      locatingWithReGeocode: this.isNeedAddress, // 是否进行逆地理编码
      reGeocodeLanguage: AMapLocationReGeocodeLanguage.Chinese, // 逆地理编码语言为中文
      isOffset: false // 是否进行坐标偏移
    };

    // 是否需要地址信息
    if (tempMap.has('needAddress')) {
      this.isNeedAddress = tempMap.get("needAddress") as boolean ?? false;
      this.options.locatingWithReGeocode = this.isNeedAddress;
    }

    // 设置地理编码语言
    if (tempMap.has("geoLanguage")) {
      let geoLanguage: number = tempMap.get("geoLanguage") as number ?? 0;
      if (geoLanguage === 0) {
        this.options.reGeocodeLanguage = AMapLocationReGeocodeLanguage.Default;
      } else if (geoLanguage === 1) {
        this.options.reGeocodeLanguage = AMapLocationReGeocodeLanguage.Chinese;
      } else {
        this.options.reGeocodeLanguage = AMapLocationReGeocodeLanguage.English;
      }
    }

    // 设置是否单次定位
    if (tempMap.has("onceLocation")) {
      this.onceLocation = tempMap.get("onceLocation") as boolean ?? true;
    } else {
      this.onceLocation = true;
    }

    // 是否允许后台定位
    if (tempMap.has("allowsBackgroundLocationUpdates")) {
      this.options.allowsBackgroundLocationUpdates = map.get("allowsBackgroundLocationUpdates") as boolean ?? false;
    }

    // 设置定位距离间隔
    if (tempMap.has("locationInterval")) {
      this.options.distanceInterval = map.get("locationInterval") as number;
    }

    // 设置定位模式
    if (tempMap.has("locationMode")) {
      let locationMode: number = tempMap.get("locationMode") as number ?? 1;
      if (locationMode === 1) {
        this.options.priority = geoLocationManager.LocationRequestPriority.LOW_POWER;
      } else if (locationMode == 2) {
        this.options.priority = geoLocationManager.LocationRequestPriority.FIRST_FIX;
      } else if (locationMode === 3) {
        this.options.priority = geoLocationManager.LocationRequestPriority.ACCURACY;
      }
    }
  }

  /**
   * 开始定位
   */
  startLocation() {
    console.info(this.TAG + ' startLocation');

    // 创建定位监听器
    this.locationListener = {
      onLocationChanged: (location) => {
        console.info(this.TAG + ' onLocationChanged: ' + JSON.stringify(location));

        try {
          // 创建定位结果映射
          let m = new Map<string, Object | string | undefined>();
          let reGeo = location.reGeo;
          m.set("locationTime", this.timestampToFullDate(location.timeStamp)); // 定位时间
          m.set('latitude', location.latitude ?? ""); // 纬度
          m.set('longitude', location.longitude ?? ""); // 经度
          m.set("accuracy", location.accuracy); // 精度
          m.set("altitude", location.altitude); // 海拔
          m.set("speed", location.speed); // 速度
          m.set("country", reGeo?.country ?? ""); // 国家
          m.set("province", reGeo?.province ?? ""); // 省份
          m.set("city", reGeo?.city ?? ""); // 城市
          m.set("district", reGeo?.district ?? ""); // 区县
          m.set("street", reGeo?.street ?? ""); // 街道
          m.set("streetNumber", reGeo?.number ?? ""); // 门牌号
          m.set("cityCode", reGeo?.citycode ?? ""); // 城市编码
          m.set("adCode", reGeo?.adcode ?? ""); // 区域编码
          m.set("address", reGeo?.address ?? "");
          m.set("description", reGeo?.desc ?? "");
          m.set("pluginKey", this.pluginKey);
          this.eventSink?.success(m);
        } catch (e) {
          console.info(this.TAG + ' error: ' + JSON.stringify(e));
          let m = new Map<string, Object | string | undefined>();
          m.set('errorCode', -1);
          m.set('errorInfo', JSON.stringify(e));
          m.set("pluginKey", this.pluginKey);
          this.eventSink?.success(m);
        }
      },
      onLocationError: (error) => {
        console.info(this.TAG + ' error: ' + JSON.stringify(error));
        let m = new Map<string, Object | string | undefined>();
        m.set('errorCode', error.errorCode);
        m.set('errorInfo', error.errorMsg);
        m.set("pluginKey", this.pluginKey);
        this.eventSink?.success(m);
      }
    };

    if (this.locationManager === undefined) {
      this.locationManager = new AMapLocationManagerImpl(this.context);
    }

    if (this.onceLocation) {
      this.locationManager?.setLocationListener(AMapLocationType.Single, this.locationListener);
      this.locationManager?.setLocationOption(AMapLocationType.Single, this.options);
      this.locationManager?.requestSingleLocation();
    } else {
      this.locationManager?.setLocationListener(AMapLocationType.Updating, this.locationListener);
      this.locationManager?.setLocationOption(AMapLocationType.Updating, this.options);
      this.locationManager?.startUpdatingLocation();
      // 开启后台定位任务
      if (this.options.allowsBackgroundLocationUpdates) {
        this.locationManager.startContinuousTask();
      }
    }
  }

  /**
   * 停止定位
   */
  stopLocation() {
    if (this.locationManager === undefined) {
      return;
    }

    if (!this.onceLocation) {
      this.locationManager?.stopUpdatingLocation();
      // 停止后台定位任务
      if (this.options.allowsBackgroundLocationUpdates) {
        this.locationManager.stopContinuousTask();
      }
    }
  }

  /**
   * 销毁定位实例
   */
  destroy() {
    if (this.locationManager === undefined) {
      return;
    }
    
    this.locationManager?.stopUpdatingLocation();
    this.locationManager?.stopContinuousTask();
    this.locationManager = undefined;
  }

  /**
   * 设置事件接收器
   * @param eventSink 事件接收器
   */
  setEventSink(eventSink: EventSink) {
    this.eventSink = eventSink;
  }

  /**
   * 将时间戳转换为完整日期字符串
   * @param timestamp 时间戳
   * @returns 格式化的日期字符串
   */
  private timestampToFullDate(timestamp: number): string {
    const date = new Date(timestamp);
    return date.toISOString().replace('T', ' ').substring(0, 19);
  }
}
