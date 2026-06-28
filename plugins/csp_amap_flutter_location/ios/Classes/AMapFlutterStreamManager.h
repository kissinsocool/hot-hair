//
//  AMapFlutterStreamManager.h
//  amap_location_flutter_plugin
//
//  Created by ldj on 2018/10/30.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

@class AMapFlutterStreamHandler;

/**
 * 高德Flutter流管理器类
 * 负责管理Flutter与原生端之间的事件流通信
 * 使用单例模式确保全局唯一实例
 */
@interface AMapFlutterStreamManager : NSObject
/**
 * 获取共享实例
 * @return 流管理器的单例对象
 */
+ (instancetype)sharedInstance;

/**
 * 流处理器
 * 用于处理Flutter与原生端之间的事件流
 */
@property (nonatomic, strong) AMapFlutterStreamHandler* streamHandler;

@end

/**
 * 高德Flutter流处理器类
 * 实现FlutterStreamHandler协议
 * 负责处理Flutter端的事件监听和取消监听
 */
@interface AMapFlutterStreamHandler : NSObject<FlutterStreamHandler>
/**
 * 事件接收器
 * 用于向Flutter端发送事件（如定位结果）
 */
@property (nonatomic, strong, nullable) FlutterEventSink eventSink;

@end
NS_ASSUME_NONNULL_END
