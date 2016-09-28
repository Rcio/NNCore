//
//  NNDeviceManager.h
//  NNCore
//
//  Created by Rico 13-7-11.
//  Copyright (c) 2013年 Rcio Wang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Reachability.h"

extern NSString *kNNNetworkStatusChange;

@interface NNDeviceManager : NSObject

@property (nonatomic, readonly) NetworkStatus netStatus;
@property (nonatomic, copy) NSString *ipAddress;

@property (nonatomic, readonly) NSString *deviceID;
@property (nonatomic, readonly) NSString *platform;

@property (nonatomic, readonly) NSString *deviceVersionString;
@property (nonatomic, readonly) NSInteger deviceMajorVersion;
@property (nonatomic, readonly) NSInteger deviceMinorVersion;
@property (nonatomic, readonly) NSInteger deviceMicroVersion;

@property (nonatomic, readonly) float batteryLevel;
@property (nonatomic, readonly) UInt64 freeDiskSpace;
@property (nonatomic, readonly) UInt64 totalDiskSpace;

@property (nonatomic, readonly) float scale;

+ (NNDeviceManager *)sharedManager;

@end
