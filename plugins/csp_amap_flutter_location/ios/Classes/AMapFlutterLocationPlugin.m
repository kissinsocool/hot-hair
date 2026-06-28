#import "AMapFlutterLocationPlugin.h"
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import "AMapFlutterStreamManager.h"

/**
 * 高德Flutter定位管理器
 * 继承自AMapLocationManager，添加Flutter相关功能
 */
@interface AMapFlutterLocationManager : AMapLocationManager

/**
 * 是否单次定位
 * true表示单次定位，false表示连续定位
 */
@property (nonatomic, assign) BOOL onceLocation;

/**
 * Flutter结果回调
 * 用于向Flutter返回定位结果
 */
@property (nonatomic, copy) FlutterResult flutterResult;

/**
 * 插件唯一标识符
 * 用于区分不同的定位实例
 */
@property (nonatomic, strong) NSString *pluginKey;

/**
 * iOS 14精确定位目的key
 * 用于请求精确定位权限
 */
@property (nonatomic, copy) NSString *fullAccuracyPurposeKey;


@end

/**
 * 高德Flutter定位管理器实现
 */
@implementation AMapFlutterLocationManager

/**
 * 初始化方法
 * 设置默认值
 */
- (instancetype)init {
    self = [super init];
    if (self) {
        _onceLocation = false;
        _fullAccuracyPurposeKey = nil;
    }
    return self;
}

@end

/**
 * 高德Flutter定位插件
 * 实现AMapLocationManagerDelegate协议
 */
@interface AMapFlutterLocationPlugin()<AMapLocationManagerDelegate>

/**
 * 插件字典
 * 存储多个定位管理器实例，支持多个定位实例同时工作
 */
@property (nonatomic, strong) NSMutableDictionary<NSString*, AMapFlutterLocationManager*> *pluginsDict;

@end

/**
 * 高德Flutter定位插件实现
 */
@implementation AMapFlutterLocationPlugin

/**
 * 插件注册方法
 * 注册方法通道和事件通道
 * @param registrar Flutter插件注册器
 */
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    // 创建方法通道
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"csp_amap_flutter_location"
                                     binaryMessenger:[registrar messenger]];
    AMapFlutterLocationPlugin* instance = [[AMapFlutterLocationPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    
    // 创建事件通道
    FlutterEventChannel *eventChanel = [FlutterEventChannel eventChannelWithName:@"csp_amap_flutter_location_stream" binaryMessenger:[registrar messenger]];
    [eventChanel setStreamHandler:[[AMapFlutterStreamManager sharedInstance] streamHandler]];
        
}

/**
 * 初始化方法
 * 创建插件字典
 */
- (instancetype)init {
    if ([super init] == self) {
        _pluginsDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

/**
 * 处理Flutter方法调用
 * @param call 方法调用对象
 * @param result 结果回调
 */
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        // 获取平台版本
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"startLocation" isEqualToString:call.method]){
        // 开始定位
        [self startLocation:call result:result];
    }else if ([@"stopLocation" isEqualToString:call.method]){
        // 停止定位
        [self stopLocation:call];
        result(@YES);
    }else if ([@"setLocationOption" isEqualToString:call.method]){
        // 设置定位参数
        [self setLocationOption:call];
    }else if ([@"destroy" isEqualToString:call.method]){
        // 销毁定位实例
        [self destroyLocation:call];
    }else if ([@"setApiKey" isEqualToString:call.method]){
        // 设置API Key
        NSString *apiKey = call.arguments[@"ios"];
        if (apiKey && [apiKey isKindOfClass:[NSString class]]) {
            [AMapServices sharedServices].apiKey = apiKey;
            result(@YES);
        }else {
            result(@NO);
        }
    }else if ([@"getSystemAccuracyAuthorization" isEqualToString:call.method]) {
        // 获取系统定位精度授权状态
        [self getSystemAccuracyAuthorization:call result:result];
    } else if ([@"updatePrivacyStatement" isEqualToString:call.method]) {
        // 更新隐私政策设置
        [self updatePrivacyStatement:call.arguments];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

/**
 * 更新隐私政策设置
 * 适配高德地图SDK隐私合规要求
 * @param arguments 隐私政策参数
 */
- (void)updatePrivacyStatement:(NSDictionary *)arguments {
    // 检查定位SDK版本是否支持隐私合规接口
    if ((AMapLocationVersionNumber) < 20800) {
        NSLog(@"当前定位SDK版本没有隐私合规接口，请升级定位SDK到2.8.0及以上版本");
        return;
    }
    if (arguments == nil) {
        return;
    }
    // 设置隐私政策是否包含高德隐私政策并展示
    if (arguments[@"hasContains"] != nil && arguments[@"hasShow"] != nil) {
        [AMapLocationManager updatePrivacyShow:[arguments[@"hasShow"] integerValue] privacyInfo:[arguments[@"hasContains"] integerValue]];
    }
    // 设置隐私政策是否已同意
    if (arguments[@"hasAgree"] != nil) {
        [AMapLocationManager updatePrivacyAgree:[arguments[@"hasAgree"] integerValue]];
    }
}

/**
 * 获取系统定位精度授权状态
 * 适配iOS 14定位新特性
 * @param call 方法调用对象
 * @param result 结果回调
 */
- (void)getSystemAccuracyAuthorization:(FlutterMethodCall*)call result:(FlutterResult)result {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
    // 检查是否为iOS 14及以上系统
    if (@available(iOS 14.0, *)) {
        AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
        CLAccuracyAuthorization curacyAuthorization = [manager currentAuthorization];
        result(@(curacyAuthorization));
    }
#else
    if (result) {
        // 如果不是iOS 14，则定位精度权限默认为高精度
        result(@(0));
    }
#endif
}

/**
 * 开始定位
 * 根据是否单次定位设置不同的定位方式
 * @param call 方法调用对象
 * @param result 结果回调
 */
- (void)startLocation:(FlutterMethodCall*)call result:(FlutterResult)result
{
    // 获取定位管理器
    AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
    if (!manager) {
        return;
    }

    // 单次定位模式
    if (manager.onceLocation) {
        NSLog(@"开始设置----manager requestLocationWithReGeocode: completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error)xxxxxxxxxx当前manager.locatingWithReGeocode是----%d",manager.locatingWithReGeocode);
        // 请求单次定位，并设置回调
        [manager requestLocationWithReGeocode:manager.locatingWithReGeocode completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
            [self handlePlugin:manager.pluginKey location:location reGeocode:regeocode error:error];
        }];
    } else {
        // 连续定位模式
        NSLog(@"startLocation");
        [manager setFlutterResult:result];
        [manager startUpdatingLocation];
    }
}

/**
 * 停止定位
 * 停止定位管理器的更新
 * @param call 方法调用对象
 */
- (void)stopLocation:(FlutterMethodCall*)call
{
    // 获取定位管理器
    AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
    if (!manager) {
        return;
    }

    // 清除结果回调并停止定位
    [manager setFlutterResult:nil];
    [[self locManagerWithCall:call] stopUpdatingLocation];
}

/**
 * 设置定位参数
 * 根据Flutter传递的参数配置定位选项
 * @param call 方法调用对象
 */
- (void)setLocationOption:(FlutterMethodCall*)call
{
    // 获取定位管理器
    AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
    if (!manager) {
        return;
    }
    
    // 设置是否需要地址信息
    NSNumber *needAddress = call.arguments[@"needAddress"];
    if (needAddress) {
        [manager setLocatingWithReGeocode:[needAddress boolValue]];
    }
        
    // 设置逆地理编码语言
    NSNumber *geoLanguage = call.arguments[@"geoLanguage"];
    if (geoLanguage) {
        if ([geoLanguage integerValue] == 0) {
            // 默认语言
            [AMapServices sharedServices].regionLanguageType = AMapRegionLanguageTypeZhHans;
        } else if ([geoLanguage integerValue] == 1) {
            // 中文
            [AMapServices sharedServices].regionLanguageType = AMapRegionLanguageTypeZhHans;
        } else if ([geoLanguage integerValue] == 2) {
            // 英文
            [AMapServices sharedServices].regionLanguageType = AMapRegionLanguageTypeEn;
        }
    }

    // 设置是否单次定位
    NSNumber *onceLocation = call.arguments[@"onceLocation"];
    if (onceLocation) {
        manager.onceLocation = [onceLocation boolValue];
    }

    // 设置是否允许系统暂停定位
    NSNumber *pausesLocationUpdatesAutomatically = call.arguments[@"pausesLocationUpdatesAutomatically"];
    if (pausesLocationUpdatesAutomatically) {
        [manager setPausesLocationUpdatesAutomatically:[pausesLocationUpdatesAutomatically boolValue]];
    }
    //设置是否允许后台定位
    NSNumber *allowsBackgroundLocationUpdates = call.arguments[@"allowsBackgroundLocationUpdates"];
    if (allowsBackgroundLocationUpdates) {
        manager.allowsBackgroundLocationUpdates = [allowsBackgroundLocationUpdates boolValue];
    }
    
    // 设置期望的定位精度
    NSNumber *desiredAccuracy = call.arguments[@"desiredAccuracy"];
    if (desiredAccuracy) {
        
        if (desiredAccuracy.integerValue == 0) {
            // 最高精度
            [manager setDesiredAccuracy:kCLLocationAccuracyBest];
        } else if (desiredAccuracy.integerValue == 1){
            // 适用于导航场景的高精度
            [manager setDesiredAccuracy:kCLLocationAccuracyBestForNavigation];
        } else if (desiredAccuracy.integerValue == 2){
            // 10米
            [manager setDesiredAccuracy:kCLLocationAccuracyNearestTenMeters];
        } else if (desiredAccuracy.integerValue == 3){
            // 100米
            [manager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
        } else if (desiredAccuracy.integerValue == 4){
            // 1000米
            [manager setDesiredAccuracy:kCLLocationAccuracyKilometer];
        } else if (desiredAccuracy.integerValue == 5){
            // 3000米
            [manager setDesiredAccuracy:kCLLocationAccuracyThreeKilometers];
        }
    }
    
    // 设置定位最小更新距离
    NSNumber *distanceFilter = call.arguments[@"distanceFilter"];
    if (distanceFilter) {
        if (distanceFilter.doubleValue == -1) {
            // 不限制距离
            [manager setDistanceFilter:kCLDistanceFilterNone];
        } else if (distanceFilter.doubleValue > 0) {
            // 设置最小更新距离
            [manager setDistanceFilter:distanceFilter.doubleValue];
        }
    }
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
    if (@available(iOS 14.0, *)) {
        NSNumber *accuracyAuthorizationMode = call.arguments[@"locationAccuracyAuthorizationMode"];
        if (accuracyAuthorizationMode) {
            if ([accuracyAuthorizationMode integerValue] == 0) {
                [manager setLocationAccuracyMode:AMapLocationFullAndReduceAccuracy];
            } else if ([accuracyAuthorizationMode integerValue] == 1) {
                [manager setLocationAccuracyMode:AMapLocationFullAccuracy];
            } else if ([accuracyAuthorizationMode integerValue] == 2) {
                [manager setLocationAccuracyMode:AMapLocationReduceAccuracy];
            }
        }
        
        NSString *fullAccuracyPurposeKey = call.arguments[@"fullAccuracyPurposeKey"];
        if (fullAccuracyPurposeKey) {
            manager.fullAccuracyPurposeKey = fullAccuracyPurposeKey;
        }
    }
#endif
}

- (void)destroyLocation:(FlutterMethodCall*)call
{
    AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
    if (!manager) {
        return;
    }
    
    @synchronized (self) {
        if (manager.pluginKey) {
            [_pluginsDict removeObjectForKey:manager.pluginKey];
        }
    }
    
}

- (void)handlePlugin:(NSString *)pluginKey location:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode error:(NSError *)error
{
    if (!pluginKey || ![[AMapFlutterStreamManager sharedInstance] streamHandler].eventSink) {
        return;
    }
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:1];
    [dic setObject:[self getFormatTime:[NSDate date]] forKey:@"callbackTime"];
    [dic setObject:pluginKey forKey:@"pluginKey"];
    
    if (location) {
        [dic setObject:[self getFormatTime:location.timestamp] forKey:@"locTime"];
        [dic setValue:@1 forKey:@"locationType"];
        [dic setObject:[NSString stringWithFormat:@"%f",location.coordinate.latitude] forKey:@"latitude"];
        [dic setObject:[NSString stringWithFormat:@"%f",location.coordinate.longitude] forKey:@"longitude"];
        [dic setValue:[NSNumber numberWithDouble:location.horizontalAccuracy] forKey:@"accuracy"];
        [dic setValue:[NSNumber numberWithDouble:location.altitude] forKey:@"altitude"];
        [dic setValue:[NSNumber numberWithDouble:location.course] forKey:@"bearing"];
        [dic setValue:[NSNumber numberWithDouble:location.speed] forKey:@"speed"];
        
        if (reGeocode) {
            if (reGeocode.country) {
                [dic setValue:reGeocode.country forKey:@"country"];
            }
            
            if (reGeocode.province) {
                [dic setValue:reGeocode.province forKey:@"province"];
            }
            
            if (reGeocode.city) {
                [dic setValue:reGeocode.city forKey:@"city"];
            }
            
            if (reGeocode.district) {
                [dic setValue:reGeocode.district forKey:@"district"];
            }
            
            if (reGeocode.street) {
                [dic setValue:reGeocode.street forKey:@"street"];
            }
            
            if (reGeocode.number) {
                [dic setValue:reGeocode.number forKey:@"streetNumber"];
            }
            
            if (reGeocode.citycode) {
                [dic setValue:reGeocode.citycode forKey:@"cityCode"];
            }

            if (reGeocode.adcode) {
                [dic setValue:reGeocode.adcode forKey:@"adCode"];
            }
            
            if (reGeocode.description) {
                [dic setValue:reGeocode.formattedAddress forKey:@"description"];
            }
                        
            if (reGeocode.formattedAddress.length) {
                [dic setObject:reGeocode.formattedAddress forKey:@"address"];
            }
        }
        
    } else {
        [dic setObject:@"-1" forKey:@"errorCode"];
        [dic setObject:@"location is null" forKey:@"errorInfo"];
        
    }
    
    if (error) {
        [dic setObject:[NSNumber numberWithInteger:error.code]  forKey:@"errorCode"];
        [dic setObject:error.description forKey:@"errorInfo"];
    }
        
    [[AMapFlutterStreamManager sharedInstance] streamHandler].eventSink(dic);
    //NSLog(@"x===%f,y===%f",location.coordinate.latitude,location.coordinate.longitude);
}

- (AMapFlutterLocationManager *)locManagerWithCall:(FlutterMethodCall*)call {
    
    if (!call || !call.arguments || !call.arguments[@"pluginKey"] || [call.arguments[@"pluginKey"] isKindOfClass:[NSString class]] == NO) {
        return nil;
    }
    
    NSString *pluginKey = call.arguments[@"pluginKey"];
    
    AMapFlutterLocationManager *manager = nil;
    @synchronized (self) {
            manager = [_pluginsDict objectForKey:pluginKey];
    }
    
    if (!manager) {
        manager = [[AMapFlutterLocationManager alloc] init];
        if (manager == nil && (AMapLocationVersionNumber) >= 20800) {
            NSAssert(manager,@"AMapLocationManager初始化失败，定位SDK2.8.0及以上，请务必确保调用SDK任何接口前先调用更新隐私合规updatePrivacyShow:privacyInfo、updatePrivacyAgree两个接口");
        }
        manager.pluginKey = pluginKey;
        NSNumber *locatingWithReGeocode = call.arguments[@"locatingWithReGeocode"];
        manager.locatingWithReGeocode = [locatingWithReGeocode boolValue];
        manager.delegate = self;
        @synchronized (self) {
            [_pluginsDict setObject:manager forKey:pluginKey];
        }
    }
    return manager;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000

/**
 *  @brief 当plist配置NSLocationTemporaryUsageDescriptionDictionary且desiredAccuracyMode设置CLAccuracyAuthorizationFullAccuracy精确定位模式时，如果用户只授权模糊定位，会调用代理的此方法。此方法实现调用申请临时精确定位权限API即可：
 *  [manager requestTemporaryFullAccuracyAuthorizationWithPurposeKey:@"PurposeKey" completion:^(NSError *error){
 *     if(completion){
 *        completion(error);
 *     }
 *  }]; (必须调用,不然无法正常获取临时精确定位权限)
 *  @param manager 定位 AMapLocationManager 类。
 *  @param locationManager 需要申请临时精确定位权限的locationManager。
 *  @param completion 临时精确定位权限API回调结果，error: 直接返回系统error即可。
 *  @since 2.6.7
 */
- (void)amapLocationManager:(AMapLocationManager *)manager doRequireTemporaryFullAccuracyAuth:(CLLocationManager*)locationManager completion:(void(^)(NSError *error))completion {
    if (@available(iOS 14.0, *)) {
        if ([manager isKindOfClass:[AMapFlutterLocationManager class]]) {
            AMapFlutterLocationManager *flutterLocationManager = (AMapFlutterLocationManager*)manager;
            if (flutterLocationManager.fullAccuracyPurposeKey && [flutterLocationManager.fullAccuracyPurposeKey length] > 0) {
                NSDictionary *locationTemporaryDictionary = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationTemporaryUsageDescriptionDictionary"];
                BOOL hasLocationTemporaryKey = locationTemporaryDictionary != nil && locationTemporaryDictionary.count != 0;
                if (hasLocationTemporaryKey) {
                    if ([locationTemporaryDictionary objectForKey:flutterLocationManager.fullAccuracyPurposeKey]) {
                        [locationManager requestTemporaryFullAccuracyAuthorizationWithPurposeKey:flutterLocationManager.fullAccuracyPurposeKey completion:^(NSError * _Nullable error) {
                            if (completion) {
                                completion(error);
                            }
                   
                        }];
                    } else {
                        NSLog(@"[AMapLocationKit] 要在iOS 14及以上版本使用精确定位, 在amap_location_option.dart 中配置的fullAccuracyPurposeKey的key不包含在infoPlist中,请检查配置的key是否正确");
                    }
                } else {
                    NSLog(@"[AMapLocationKit] 要在iOS 14及以上版本使用精确定位, 需要在Info.plist中添加NSLocationTemporaryUsageDescriptionDictionary字典，且自定义Key描述精确定位的使用场景。");
                }
        
            } else {
                NSLog(@"[AMapLocationKit] 要在iOS 14及以上版本使用精确定位, 需要在amap_location_option.dart 中配置对应场景下fullAccuracyPurposeKey的key。注意：这个key要和infoPlist中的配置一样");
            }
        }
    }
}
#endif

/**
 *  @brief 当plist配置NSLocationAlwaysUsageDescription或者NSLocationAlwaysAndWhenInUseUsageDescription，并且[CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined，会调用代理的此方法。
     此方法实现调用申请后台权限API即可：[locationManager requestAlwaysAuthorization](必须调用,不然无法正常获取定位权限)
 *  @param manager 定位 AMapLocationManager 类。
 *  @param locationManager  需要申请后台定位权限的locationManager。
 *  @since 2.6.2
 */
- (void)amapLocationManager:(AMapLocationManager *)manager doRequireLocationAuth:(CLLocationManager*)locationManager
{
    [locationManager requestWhenInUseAuthorization];
}

 /**
 *  @brief 当定位发生错误时，会调用代理的此方法。
 *  @param manager 定位 AMapLocationManager 类。
 *  @param error 返回的错误，参考 CLError 。
 */
- (void)amapLocationManager:(AMapLocationManager *)manager didFailWithError:(NSError *)error
{
    [self handlePlugin:((AMapFlutterLocationManager *)manager).pluginKey location:nil reGeocode:nil error:error];
}


/**
 *  @brief 连续定位回调函数.注意：如果实现了本方法，则定位信息不会通过amapLocationManager:didUpdateLocation:方法回调。
 *  @param manager 定位 AMapLocationManager 类。
 *  @param location 定位结果。
 *  @param reGeocode 逆地理信息。
 */
- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode
{
    [self handlePlugin:((AMapFlutterLocationManager *)manager).pluginKey location:location reGeocode:reGeocode error:nil];
}

- (NSString *)getFormatTime:(NSDate*)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY-MM-dd HH:mm:ss"];
    NSString *timeString = [formatter stringFromDate:date];
    return timeString;
}

@end
