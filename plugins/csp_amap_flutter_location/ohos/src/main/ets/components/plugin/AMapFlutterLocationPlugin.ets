import {
  AMapLocationManagerImpl,
  AMapLocationOption,
  AMapLocationReGeocodeLanguage,
  AMapLocationType,
  IAMapLocationListener,
} from '@amap/amap_lbs_location';
import {
  AbilityAware,
  AbilityPluginBinding,
  Any,
  EventChannel,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  StringUtils,
  ToolUtils,
} from '@ohos/flutter_ohos';
import { EventSink, StreamHandler } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import { abilityAccessCtrl, bundleManager, common, PermissionRequestResult, Permissions,
  UIAbility } from '@kit.AbilityKit';
import { CommonConstants } from './CommonConstants';
import { BusinessError } from '@ohos.base';
import { AMapPrivacyShowStatus, AMapPrivacyInfoStatus, AMapPrivacyAgreeStatus } from '@amap/amap_lbs_common';
import geoLocationManager from '@ohos.geoLocationManager';
import AMapLocationClientImpl from './AMapLocationClientImpl';

/**
 * 高德地图定位Flutter插件鸿蒙平台实现类
 * 负责Flutter端与鸿蒙原生端的通信和定位功能实现
 */
export default class AMapFlutterLocationPlugin implements FlutterPlugin, MethodCallHandler, StreamHandler{
  // 方法通道，用于Flutter调用原生方法
  private channel: MethodChannel | null = null;
  // 事件通道，用于原生端向Flutter发送定位结果
  private eventChannel: EventChannel | null = null;
  // 事件接收器，用于向Flutter端发送事件
  private eventSink?: EventSink
  // 方法通道名称
  private CHANNEL_METHOD_LOCATION: string = "csp_amap_flutter_location"
  // 事件通道名称
  private CHANNEL_STREAM_LOCATION: string = "csp_amap_flutter_location_stream"
  // 应用上下文
  private context:Context|undefined
  // 日志标签
  private TAG = "AMapFlutterLocationPlugin"

  // 定位客户端映射表，支持多个定位实例
  private locationClientMap: Map<string, AMapLocationClientImpl> = new Map<string, AMapLocationClientImpl>();

  /**
   * 构造函数
   */
  constructor() {
  }

  /**
   * 当Flutter端开始监听事件流时调用
   * @param args 监听参数
   * @param events 事件接收器
   */
  onListen(args: Any, events: EventSink): void {
    console.info(this.TAG + ' eventChannel onListen: events is ' + events)
    this.eventSink = events;

    // 更新所有定位客户端的事件接收器
    this.locationClientMap.forEach((client) => {
      client.setEventSink(events);
    });

    console.info(this.TAG + ' eventChannel onListen2: eventSink is ' + this.eventSink)
  }

  /**
   * 当Flutter端取消监听事件流时调用
   * @param args 取消监听参数
   */
  onCancel(args: Any): void {
    console.info(this.TAG + ' setStreamHandler onCancel ')
    this.eventSink = undefined;

    // 停止所有定位客户端
    this.locationClientMap.forEach((client) => {
      client.stopLocation();
    });
  }

  /**
   * 获取唯一类名
   * @return 类名字符串
   */
  getUniqueClassName(): string {
    return "AMapFlutterLocationPlugin"
  }

  /**
   * 插件附加到引擎时调用
   * 初始化通道
   * @param binding Flutter插件绑定对象
   */
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    console.info(this.TAG + ' onLocationChanged  onAttachedToEngine  ')
    if (this.context === undefined) {
      this.context = binding.getApplicationContext()
    }

    // 初始化方法通道
    this.channel = new MethodChannel(binding.getBinaryMessenger(), this.CHANNEL_METHOD_LOCATION);
    this.channel.setMethodCallHandler(this)

    // 初始化事件通道
    this.eventChannel = new EventChannel(binding.getBinaryMessenger(), this.CHANNEL_STREAM_LOCATION);
    this.eventChannel.setStreamHandler(this)
  }

  /**
   * 插件从引擎分离时调用
   * @param binding Flutter插件绑定对象
   */
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }

    // 销毁所有定位客户端
    this.locationClientMap.forEach((client) => {
      client.destroy();
    });
    this.locationClientMap.clear();
  }

  /**
   * 处理来自Flutter的方法调用
   * @param call 方法调用对象
   * @param result 结果回调对象
   */
  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case "getPlatformVersion":
        // 获取平台版本
        result.success("OpenHarmony ^ ^ ")
        break
      case "updatePrivacyStatement":
        // 更新隐私政策设置
        this.updatePrivacyStatement(call.args);
        break
      case "setApiKey":
        // 设置API Key
        this.setApiKey(call.args)
        break
      case "setLocationOption":
        // 设置定位参数
        this.setLocationOption(call.args)
        break
      case "startLocation":
        // 开始定位
        this.startLocation(call.args)
        break
      case "stopLocation":
        // 停止定位
        this.stopLocation(call.args)
        break
      case "destroy":
        // 销毁定位实例
        this.destroy(call.args)
        break
      default:
      // 未实现的方法
        result.notImplemented()
    }
  }

  /**
   * 更新隐私政策设置
   * @param map 隐私政策参数
   */
  updatePrivacyStatement(map: Any) {
    if (!this.context) {
      return
    }
    let hasContains: Any = this.argumentParse('hasContains', map)
    let hasShow: Any = this.argumentParse('hasShow', map)
    let hasAgree: Any = this.argumentParse('hasAgree', map)
    if (hasContains != null && hasShow != null) {
      // 设置隐私政策已展示并包含高德隐私政策
      let hasContainsBool:boolean = hasContains as boolean ?? false
      let hasShowBool:boolean = hasShow as boolean ?? false
      AMapLocationManagerImpl.updatePrivacyShow(hasContainsBool ? AMapPrivacyShowStatus.DidShow : AMapPrivacyShowStatus.NotShow, hasShowBool ? AMapPrivacyInfoStatus.DidContain : AMapPrivacyInfoStatus.NotContain,
        this.context)
    }
    if (hasAgree != null) {
      let hasAgreeBool:boolean = hasAgree as boolean ?? false
      // 设置用户已同意隐私政策
      AMapLocationManagerImpl.updatePrivacyAgree(hasAgreeBool ? AMapPrivacyAgreeStatus.DidAgree : AMapPrivacyAgreeStatus.NotAgree, this.context)
    }

  }

  /**
   * 设置API Key
   * @param map 包含API Key的参数映射
   */
  setApiKey(map: Any) {
    try {
      let apiKey: string = this.argumentParse('ohos', map)
      if (StringUtils.isNotEmpty(apiKey)) {
        console.info(this.TAG + ' setApiKey: ' + apiKey)
        AMapLocationManagerImpl.setApiKey(apiKey)
      }

    } catch (e) {
      console.info(this.TAG + ' setApiKey error: ' + e)
    }
  }

  /**
   * 设置定位参数
   * @param map 定位参数映射
   */
  setLocationOption(map: Any) {
    console.info(this.TAG + ' setLocationOption  map: ' + JSON.stringify(map))

    // 获取或创建定位客户端
    const locationClient = this.getLocationClientImpl(map);
    if (locationClient) {
      // 将Any类型转换为Map类型
      const optionMap:Map<string, Any> = new Map<string, Any>();
      if (map instanceof Map) {
        map.forEach((value:Any, key:string) => {
          console.info(this.TAG,`setLocationMap key:${key} value:${value}`)
          optionMap.set(key, value);
        });
      } else if (typeof map === 'object' && map !== null) {
        Object.keys(map).forEach(key => {
          console.info(this.TAG,`setLocationObje key:${key} value:${map[key]}`)
          optionMap.set(key, map[key]);
        });
      }

      // 设置定位参数
      locationClient.setLocationOption(optionMap);
    }
  }

  /**
   * 开始定位
   * @param map 参数映射
   */
  startLocation(map: Any) {
    console.info(this.TAG + ' startLocation')

    // 检查定位权限
    this.checkPermissions();

    // 获取或创建定位客户端
    const locationClient = this.getLocationClientImpl(map);
    if (locationClient) {
      // 开始定位
      locationClient.startLocation();
    }
  }

  /**
   * 停止定位
   * @param map 参数映射
   */
  stopLocation(map: Any) {
    // 获取定位客户端
    const locationClient = this.getLocationClientImpl(map);
    if (locationClient) {
      // 停止定位
      locationClient.stopLocation();
    }
  }

  /**
   * 销毁定位实例
   * @param map 参数映射
   */
  destroy(map: Any) {
    // 获取插件唯一标识符
    const pluginKey = this.getPluginKeyFromArgs(map);
    if (!pluginKey) {
      return;
    }

    // 获取定位客户端
    const locationClient = this.getLocationClientImpl(map)
    if (locationClient) {
      // 销毁定位客户端
      locationClient.destroy();
      // 从映射表中移除
      this.locationClientMap.delete(pluginKey);
    }
  }

  /**
   * 获取或创建定位客户端实现
   * @param map 参数映射
   * @returns 定位客户端实现
   */
  private getLocationClientImpl(map: Any): AMapLocationClientImpl | undefined {
    if (!this.context) {
      return undefined;
    }

    // 获取插件唯一标识符
    const pluginKey = this.getPluginKeyFromArgs(map);
    if (!pluginKey) {
      return undefined;
    }

    // 从映射表中获取定位客户端
    let locationClient = this.locationClientMap.get(pluginKey);

    // 如果不存在则创建新的定位客户端
    if (!locationClient) {
      locationClient = new AMapLocationClientImpl(this.context, pluginKey, this.eventSink);
      this.locationClientMap.set(pluginKey, locationClient);
    }

    return locationClient;
  }

  /**
   * 从参数中获取插件唯一标识符
   * @param map 参数映射
   * @returns 插件唯一标识符
   */
  private getPluginKeyFromArgs(map: Any): string {
    let pluginKey = this.argumentParse('pluginKey', map) as string;
    return pluginKey;
  }

  /**
   * 从参数映射中解析参数
   * @param key 参数键
   * @param map 参数映射
   * @returns 参数值
   */
  private argumentParse(key: string, map: Any): Any {
    if (map instanceof Map) {
      return map.get(key);
    } else if (typeof map === 'object' && map !== null) {
      return map[key];
    }
    return null;
  }

  async checkPermissions(): Promise<void> {
    console.info(this.TAG + ' onLocationChanged  checkPermissions')
    const permissions: Array<Permissions> = ['ohos.permission.LOCATION','ohos.permission.LOCATION_IN_BACKGROUND','ohos.permission.APPROXIMATELY_LOCATION'];
    let grantStatus: abilityAccessCtrl.GrantStatus = await this.checkAccessToken(permissions[0]);

    if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      // 已经授权，可以继续访问目标操作
      console.info(this.TAG + ' onLocationChanged  已经授权，可以继续访问目标操作')

    } else {

      const permissions: Array<Permissions> = ['ohos.permission.LOCATION'];

      this.reqPermissionsFromUser(CommonConstants.REQUEST_PERMISSIONS);
    }
  }

  async checkAccessToken(permission: Permissions): Promise<abilityAccessCtrl.GrantStatus> {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    let grantStatus: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;

    // 获取应用程序的accessTokenID
    let tokenId: number = 0;
    try {
      let bundleInfo: bundleManager.BundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      let appInfo: bundleManager.ApplicationInfo = bundleInfo.appInfo;
      tokenId = appInfo.accessTokenId;
      console.info(this.TAG + ` tokenId is ${tokenId}`);
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      console.info(this.TAG + ` Failed to get bundle info for self. Code is ${err.code}, message is ${err.message}`);
    }

    // 校验应用是否被授予权限
    try {
      grantStatus = await atManager.checkAccessToken(tokenId, permission);
      console.info(this.TAG + ` grantStatus ${grantStatus}`);

    } catch (error) {
      let err: BusinessError = error as BusinessError;
      console.info(this.TAG + ` Failed to check access token. Code is ${err.code}, message is ${err.message}`);
    }

    return grantStatus;
  }

  reqPermissionsFromUser(permissions: Array<Permissions>): void {
    console.info(this.TAG + ` reqPermissionsFromUser`);
    let context: Context = getContext(this) as common.UIAbilityContext;
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    // requestPermissionsFromUser会判断权限的授权状态来决定是否唤起弹窗
    atManager.requestPermissionsFromUser(context, permissions).then((data: PermissionRequestResult) => {
      let grantStatus: Array<number> = data.authResults;
      console.info(this.TAG + ` reqPermissionsFromUser result grantStatus:${grantStatus}`);
      let length: number = grantStatus.length;
      for (let i = 0; i < length; i++) {
        if (grantStatus[i] === 0) {
          // 用户授权，可以继续访问目标操作
        } else {
          // 用户拒绝授权，提示用户必须授权才能访问当前页面的功能，并引导用户到系统设置中打开相应的权限
          // this.openPermissionsInSystemSettings()
          return;
        }
      }
      // 授权成功
    }).catch((err: BusinessError) => {

      console.info(this.TAG +
        ` Failed to request permissions from user. Code is ${err.code}, message is ${err.message}`);
    })
  }

  requestPermissions(): void {
    let atManager = abilityAccessCtrl.createAtManager();
    try {
      atManager.requestPermissionsFromUser(this.context, CommonConstants.REQUEST_PERMISSIONS).then((data) => {
        console.info('requestPermissionsFromUser')

        if (data.authResults[0] !== 0 || data.authResults[1] !== 0) {
          console.info('requestPermissionsFromUser return')
          return;
        }
        const that = this;

      }).catch((err: Error) => {
        console.info('requestPermissionsFromUser err' + JSON.stringify(err))
      })
    } catch (err) {
      console.info('requestPermissionsFromUser err' + JSON.stringify(err));
    }
  }

  timestampToFullDate(timestamp: number): string {
    const date = new Date(timestamp);

    const year = date.getFullYear();
    const month = ("0" + (date.getMonth() + 1)).slice(-2); // Months are zero-based
    const day = ("0" + date.getDate()).slice(-2);
    const hours = ("0" + date.getHours()).slice(-2);
    const minutes = ("0" + date.getMinutes()).slice(-2);
    const seconds = ("0" + date.getSeconds()).slice(-2);

    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  }
} 