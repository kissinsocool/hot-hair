package com.amap.flutter.csp_amap_flutter_location;

import android.content.Context;
import android.text.TextUtils;

import com.amap.api.location.AMapLocationClient;

import java.lang.reflect.Method;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** 
 * 高德地图定位SDK Flutter插件
 * 负责Flutter端与Android原生端的通信和定位功能实现
 */
public class AMapFlutterLocationPlugin implements FlutterPlugin, MethodCallHandler,
        EventChannel.StreamHandler {
  // 方法通道名称，用于Flutter调用原生方法
  private static final String CHANNEL_METHOD_LOCATION = "csp_amap_flutter_location";
  // 事件通道名称，用于原生端向Flutter发送定位结果
  private static final String CHANNEL_STREAM_LOCATION = "csp_amap_flutter_location_stream";

  // 应用上下文
  private Context mContext = null;

  // 事件接收器，用于向Flutter发送定位结果
  public static EventChannel.EventSink mEventSink = null;

  // 定位客户端映射表，支持多个定位实例
  private Map<String, AMapLocationClientImpl> locationClientMap = new ConcurrentHashMap<String, AMapLocationClientImpl>(8);

  /**
   * 处理来自Flutter的方法调用
   * @param call 方法调用对象，包含方法名和参数
   * @param result 结果回调对象
   */
  @Override
  public void onMethodCall(MethodCall call, Result result) {
    String callMethod = call.method;
    switch (call.method) {
      case "updatePrivacyStatement":
        // 更新隐私政策设置
        updatePrivacyStatement((Map)call.arguments);
        break;
      case "setApiKey":
        // 设置API Key
        setApiKey((Map) call.arguments);
        break;
      case "setLocationOption":
        // 设置定位参数
        setLocationOption((Map) call.arguments);
        break;
      case "startLocation":
        // 开始定位
        startLocation((Map) call.arguments);
        break;
      case "stopLocation":
        // 停止定位
        stopLocation((Map) call.arguments);
        break;
      case "destroy":
        // 销毁定位实例
        destroy((Map) call.arguments);
        break;
      default:
        // 未实现的方法
        result.notImplemented();
        break;
    }
  }

  /**
   * 当Flutter端开始监听事件流时调用
   * @param o 监听参数
   * @param eventSink 事件接收器
   */
  @Override
  public void onListen(Object o, EventChannel.EventSink eventSink) {
    mEventSink = eventSink;
  }

  /**
   * 当Flutter端取消监听事件流时调用
   * @param o 取消监听参数
   */
  @Override
  public void onCancel(Object o) {
    // 停止所有定位客户端
    for (Map.Entry<String, AMapLocationClientImpl> entry : locationClientMap.entrySet()) {
      entry.getValue().stopLocation();
    }
  }

  /**
   * 开始定位
   * 根据参数获取定位客户端并启动定位
   * @param argsMap 参数映射
   */
  private void startLocation(Map argsMap) {
    AMapLocationClientImpl locationClientImp = getLocationClientImp(argsMap);
    if (null != locationClientImp) {
      locationClientImp.startLocation();
    }
  }

  /**
   * 停止定位
   * 根据参数获取定位客户端并停止定位
   * @param argsMap 参数映射
   */
  private void stopLocation(Map argsMap) {
    AMapLocationClientImpl locationClientImp = getLocationClientImp(argsMap);
    if (null != locationClientImp) {
      locationClientImp.stopLocation();
    }
  }

  /**
   * 销毁定位客户端
   * 释放资源并从映射表中移除
   * @param argsMap 参数映射
   */
  private void destroy(Map argsMap) {
    AMapLocationClientImpl locationClientImp = getLocationClientImp(argsMap);
    if (null != locationClientImp) {
      locationClientImp.destroy();
      // 从映射表中移除
      locationClientMap.remove(getPluginKeyFromArgs(argsMap));
    }
  }

  /**
   * 设置API Key
   * 设置高德地图Android SDK的API Key
   * @param apiKeyMap 包含API Key的映射
   */
  private void setApiKey(Map apiKeyMap) {
    if (null != apiKeyMap) {
      if (apiKeyMap.containsKey("android")
              && !TextUtils.isEmpty((String) apiKeyMap.get("android"))) {
        AMapLocationClient.setApiKey((String) apiKeyMap.get("android"));
      }
    }
  }

  /**
   * 更新隐私政策设置
   * 适配高德地图SDK隐私合规要求
   * @param privacyShowMap 隐私政策参数映射
   */
  private void updatePrivacyStatement(Map privacyShowMap) {
    if (null != privacyShowMap) {
      Class<AMapLocationClient> locationClazz = AMapLocationClient.class;

      // 设置隐私政策是否包含高德隐私政策并展示
      if (privacyShowMap.containsKey("hasContains") && privacyShowMap.containsKey("hasShow")) {
        boolean hasContains = (boolean) privacyShowMap.get("hasContains");
        boolean hasShow = (boolean) privacyShowMap.get("hasShow");
        try {
          Method showMethod = locationClazz.getMethod("updatePrivacyShow", Context.class, boolean.class, boolean.class);;
          showMethod.invoke(null, mContext, hasContains, hasShow);
        } catch (Throwable e) {
//          e.printStackTrace();
        }
      }

      // 设置隐私政策是否已同意
      if (privacyShowMap.containsKey("hasAgree")) {
        boolean hasAgree = (boolean) privacyShowMap.get("hasAgree");
        try {
          Method agreeMethod = locationClazz.getMethod("updatePrivacyAgree", Context.class, boolean.class);
          agreeMethod.invoke(null, mContext, hasAgree);
        } catch (Throwable e) {
//            e.printStackTrace();
        }
      }
    }
  }

  /**
   * 设置定位参数
   * 根据参数获取定位客户端并设置定位参数
   * @param argsMap 参数映射
   */
  private void setLocationOption(Map argsMap) {
    AMapLocationClientImpl locationClientImp = getLocationClientImp(argsMap);
    if (null != locationClientImp) {
      locationClientImp.setLocationOption(argsMap);
    }
  }

  /**
   * 插件附加到引擎时调用
   * 初始化通道和上下文
   * @param binding Flutter插件绑定对象
   */
  @Override
  public void onAttachedToEngine(FlutterPluginBinding binding) {
    if (null == mContext) {
      mContext = binding.getApplicationContext();

      /**
       * 方法调用通道
       * 用于Flutter调用原生方法
       */
      final MethodChannel channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_METHOD_LOCATION);
      channel.setMethodCallHandler(this);

      /**
       * 回调监听通道
       * 用于原生端向Flutter发送定位结果
       */
      final EventChannel eventChannel = new EventChannel(binding.getBinaryMessenger(), CHANNEL_STREAM_LOCATION);
      eventChannel.setStreamHandler(this);
    }
  }

  /**
   * 插件从引擎分离时调用
   * 销毁所有定位客户端
   * @param binding Flutter插件绑定对象
   */
  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {
    for (Map.Entry<String, AMapLocationClientImpl> entry : locationClientMap.entrySet()) {
      entry.getValue().destroy();
    }
  }

  /**
   * 获取或创建定位客户端实现
   * @param argsMap 参数映射
   * @return 定位客户端实现对象
   */
  private AMapLocationClientImpl getLocationClientImp(Map argsMap) {
    if (null == locationClientMap) {
      locationClientMap = new ConcurrentHashMap<String, AMapLocationClientImpl>(8);
    }

    String pluginKey = getPluginKeyFromArgs(argsMap);
    if (TextUtils.isEmpty(pluginKey)) {
      return null;
    }

    if (!locationClientMap.containsKey(pluginKey)) {
      AMapLocationClientImpl locationClientImp = new AMapLocationClientImpl(mContext, pluginKey, mEventSink);
      locationClientMap.put(pluginKey, locationClientImp);
    }
    return locationClientMap.get(pluginKey);
  }

  /**
   * 从参数映射中获取插件键
   * @param argsMap 参数映射
   * @return 插件键字符串
   */
  private String getPluginKeyFromArgs(Map argsMap) {
    String pluginKey = null;
    try {
      if (null != argsMap) {
        pluginKey = (String) argsMap.get("pluginKey");
      }
    } catch (Throwable e) {
      e.printStackTrace();
    }
    return pluginKey;
  }
}
