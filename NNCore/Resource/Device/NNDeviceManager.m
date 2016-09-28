//
//  NNDeviceManager.m
//  NNCore
//
//  Created by Rico 13-7-11.
//  Copyright (c) 2013年 Rcio Wang. All rights reserved.
//

#import "NNDeviceManager.h"
#import "UIDevice+Ex.h"
#import "NNNotification.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "UIDevice+Ex.h"


NSString *kNNNetworkStatusChange = @"__kNNNetworkStatusChange__";

@interface NNDeviceManager ()

@property (nonatomic, assign) NetworkStatus netStatus;

@property (nonatomic, strong) NSTimer *networkScanTimer;

@property (nonatomic, strong) Reachability *reachablility;
@property (nonatomic, assign) UInt64 freeDiskSpace;
@property (nonatomic, assign) UInt64 totalDiskSpace;
@end

@implementation NNDeviceManager
#pragma mark - Sington
+ (NNDeviceManager *)sharedManager
{
    static NNDeviceManager *_sharedManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[[self class] alloc] init];
    });
    
    return _sharedManager;
}

- (id)init {
    self = [super init];
        
//    NSAssert([NSThread isMainThread], @"NN Device Manager need be init in main thread, cause sceche a timer");

    /* 网络信息初始化 */
    _netStatus = NotReachable;
    [self refreshNetworkStatus:nil];
    
    /* 屏幕分辨率*/
    _scale = [[UIScreen mainScreen] scale];
    
    _reachablility = [Reachability reachabilityForInternetConnection];
    [_reachablility startNotifier];
    _networkScanTimer = [NSTimer scheduledTimerWithTimeInterval:3.0f target:self selector:@selector(refreshNetworkStatus:) userInfo:nil repeats:YES];
    [NNNotification listenToEvent:kReachabilityChangedNotification observer:self selector:@selector(refreshNetworkStatus:)];
    [NNNotification listenToEvent:UIApplicationWillEnterForegroundNotification observer:self selector:@selector(refreshNetworkStatus:)];
    
    /* 版本号信息初始化 */
    [self initDeviceVserionInfo];
    
    /* 设备信息 */
    _deviceID = [UIDevice wifiMacAddr];
    _platform = [UIDevice getCurrentPlatform];
    
    return self;
}

- (void)dealloc {
    [_networkScanTimer invalidate];
}

- (void)initDeviceVserionInfo {
    _deviceVersionString = [[UIDevice currentDevice] systemVersion];

    NSArray *components = [_deviceVersionString componentsSeparatedByString:@"."];
    
//    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
//    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];

    switch ([components count])
    {
        case 3:
            _deviceMicroVersion = [components[2] integerValue];//[self parseInt:[components objectAtIndex:2] formatter:formatter];
            
        case 2:
            _deviceMinorVersion = [components[1] integerValue];//[self parseInt:[components objectAtIndex:1] formatter:formatter];
            
        case 1:
            _deviceMajorVersion = [components[0] integerValue];//[self parseInt:[components objectAtIndex:0] formatter:formatter];
            break;
    }
}

- (NSString *)ipAddress {
    if (_ipAddress == nil) {
        _ipAddress = [UIDevice getCurrentIPAddress:nil];
    }
    
    return _ipAddress;
}

#pragma mark Selectors
- (void)refreshNetworkStatus:(id)sender {
    static BOOL firstTime = YES;
    
    @synchronized(self) {
        NetworkStatus networkStatus;
        Reachability *ability = [Reachability reachabilityForInternetConnection];
        if (!ability) {
            networkStatus = NotReachable;
        }
        else {
            networkStatus = [ability currentReachabilityStatus];
        }
        
        NetworkStatus oldNetStatus = self.netStatus;
        self.netStatus = networkStatus;
        if (firstTime == NO && oldNetStatus != self.netStatus) {
            [self networkStatusChangeFrom:oldNetStatus to:self.netStatus];
        }
        
        if (firstTime == YES) {
            firstTime = NO;
        }
    }
}

#pragma mark Internal Functions

/**
 * networkStatusChangeFrom:to:
 * @brief 网络状态变化后被调用，内部处理通知事宜
 */
- (void)networkStatusChangeFrom:(NSUInteger)oldNetType to:(NSUInteger)newNetType {
    self.ipAddress = nil;
    if (newNetType == ReachableViaWiFi) {
        [self startNetworkTask];
    }
    
    if (newNetType != ReachableViaWiFi) {
        [self suspendNetworkTask];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kNNNetworkStatusChange object:nil userInfo:nil];
}

- (void)startNetworkTask {
}

- (void)suspendNetworkTask {
}

- (int)parseInt:(NSString *)string formatter:(NSNumberFormatter *)formatter
{
    NSNumber *number = [formatter numberFromString:string];
    
    if (number == nil)
    {
        return 0;
    }
    
    return [number intValue];
}


- (float)batteryLevel
{

#if 0  //有审核的风险。
    NSInteger capacity = 0;
    @try {
        //return [MQQBatteryUnitTestManager shareInstance].level * 100;
        UIApplication *app = [UIApplication sharedApplication];
        if (app.applicationState == UIApplicationStateActive) {
            UIView * statusBarView = (UIView *)[app valueForKey:@"_statusBar"];
            if ([statusBarView isKindOfClass:[UIView class]]) {

                UIView * batteryItemView = nil;
                for (UIView * subView in [statusBarView subviews]) {
                    for (UIView * subSubView in [subView subviews]) {
                        NSString * className = NSStringFromClass([subSubView class]);
                        if ([className isEqualToString:@"UIStatusBarBatteryItemView"]
                            || [className isEqualToString:@"UIStatusBarBatteryPercentItemView"]) {
                            batteryItemView = subSubView;
                            break;
                        }
                    }
                }
                NSNumber * capacityNum = [batteryItemView valueForKey:@"_capacity"];
                if (nil != capacityNum) {
                    capacity = [capacityNum integerValue];
                } else {
                    NSString * percentStr = [batteryItemView valueForKey:@"_percentString"];
                    capacity = [percentStr integerValue];
                }
            }
        }

    } @catch (...) {

    }

    if (0 != capacity) {
        return (CGFloat)capacity/100;
    } else {
        return [UIDevice currentDevice].batteryLevel;
    }
#else
    return [UIDevice currentDevice].batteryLevel;
#endif
}

- (UInt64)freeDiskSpace {
    [self updateDiskSpace];
    return _freeDiskSpace;
}

- (UInt64)totalDiskSpace {
    [self updateDiskSpace];
    return _totalDiskSpace;
}

- (void)updateDiskSpace {
    static time_t lastRefreshTime = 0;
    time_t now = time(NULL);
    
    // 10s 内只读取一次
    if (now - lastRefreshTime > 10) {
        NSError *error = nil;
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSDictionary *attributesDic = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error:&error];
        
        if (error) {
            _freeDiskSpace = UINT_MAX;
            _totalDiskSpace = UINT_MAX;
            return;
        }
        
        if (nil != attributesDic) {
            NSNumber *freeFileSystemSizeInBytes = [attributesDic objectForKey:NSFileSystemFreeSize];
            _freeDiskSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
            
            NSNumber *totalFileSystemSizeInBytes = [attributesDic objectForKey:NSFileSystemSize];
            _totalDiskSpace = [totalFileSystemSizeInBytes unsignedLongLongValue];
        }
    }
}
@end
