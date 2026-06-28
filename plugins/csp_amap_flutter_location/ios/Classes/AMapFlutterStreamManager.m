//
//  AMapFlutterStreamManager.m
//  amap_location_flutter_plugin
//
//  Created by ldj on 2018/10/30.
//

#import "AMapFlutterStreamManager.h"

/**
 * 高德Flutter流管理器实现类
 * 负责管理Flutter与原生端之间的事件流通信
 */
@implementation AMapFlutterStreamManager

/**
 * 获取共享实例
 * 使用单例模式确保全局只有一个流管理器实例
 * @return 流管理器的单例对象
 */
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static AMapFlutterStreamManager *manager = nil;
    dispatch_once(&onceToken, ^{
        manager = [[AMapFlutterStreamManager alloc] init];
        AMapFlutterStreamHandler * streamHandler = [[AMapFlutterStreamHandler alloc] init];
        manager.streamHandler = streamHandler;
    });
    
    return manager;
}

@end

/**
 * 高德Flutter流处理器实现类
 * 负责处理Flutter端的事件监听和取消监听
 */
@implementation AMapFlutterStreamHandler

/**
 * 当Flutter端开始监听事件流时调用
 * 保存事件接收器以便后续发送事件
 * @param arguments Flutter端传递的参数
 * @param eventSink 事件接收器，用于向Flutter端发送事件
 * @return 错误对象，如果没有错误返回nil
 */
- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    self.eventSink = eventSink;
    return nil;
}

/**
 * 当Flutter端取消监听事件流时调用
 * 清除事件接收器
 * @param arguments Flutter端传递的参数
 * @return 错误对象，如果没有错误返回nil
 */
- (FlutterError*)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

@end
