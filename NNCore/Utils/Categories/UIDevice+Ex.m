//
//  UIDeviceEx.m
//  QQDiskLogin
//
//  Created by Rico 11-12-21.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include <assert.h>

#import <SystemConfiguration/SystemConfiguration.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <Security/Security.h>

#import "UIDevice+Ex.h"

// replace the identity with your company's domain
static  NSString *kKeyChainUDIDKey = @"WeiyunKeyChainUDIDKey";
static const char kKeychainUDIDItemIdentifier[]  = "UUID";

@implementation UIDevice(Ex)



NSString* const WIFI_INTERFACE_NAME             = @"_WIFI_INTERFACE_NAME"; 
NSString* const WIFI_INTERFACE_ADDR             = @"_WIFI_INTERFACE_ADDR";
NSString* const WIFI_INTERFACE_NETMASK          = @"_WIFI_INTERFACE_NETMASK";
NSString* const WIFI_INTERFACE_BROADCAST_ADDR   = @"_WIFI_INTERFACE_BROADCAST_ADDR";

SCNetworkReachabilityFlags	connectionFlags;
SCNetworkReachabilityRef	reachability;

/**
 *
 * get the current ip address，可以通过接口名直接获取wifi的ip，或者获取当前激活的网卡ip
 *
 */
+ (NSString*)getCurrentIPAddress:(NSString*)interfaceName
{
	BOOL success;
	struct ifaddrs* addrs;
	struct ifaddrs* cursor;
	
	success = getifaddrs(&addrs) == 0;
    NSString* ipAddr = nil;
	if (success) {
		cursor = addrs;
		while (cursor != NULL) {
			// the second test keeps from picking up the loopback address
			if (cursor->ifa_addr->sa_family == AF_INET 
				&& (cursor->ifa_flags & IFF_LOOPBACK)==0) {
                
                if (nil != interfaceName) {
                    NSString* name = [NSString stringWithUTF8String: cursor->ifa_name];
                    if ([name isEqualToString: interfaceName]) {
                        char addrBuf[INET_ADDRSTRLEN];
                        if (inet_ntop(AF_INET, &((struct sockaddr_in*)cursor->ifa_addr)->sin_addr, addrBuf, (socklen_t)sizeof(addrBuf)) == NULL)
                        {
                            addrBuf[0] = '\0';
                        }
                        ipAddr = [NSString stringWithCString:addrBuf encoding:NSUTF8StringEncoding];
//                        ipAddr = [NSString stringWithUTF8String: 
//                                  inet_ntoa(((struct sockaddr_in*)cursor->ifa_addr)->sin_addr)];
                        break;
                    }
                }else {
                    if (cursor->ifa_flags & IFF_UP) {
                        char addrBuf[INET_ADDRSTRLEN];
                        if (inet_ntop(AF_INET, &((struct sockaddr_in*)cursor->ifa_addr)->sin_addr, addrBuf, (socklen_t)sizeof(addrBuf)) == NULL)
                        {
                            addrBuf[0] = '\0';
                        }
                        ipAddr = [NSString stringWithCString:addrBuf encoding:NSUTF8StringEncoding];
//                        
//                        ipAddr = [NSString stringWithUTF8String:
//                                  inet_ntoa(((struct sockaddr_in*)cursor->ifa_addr)->sin_addr)];
                        break;
                    }
                }
				
			}
			cursor = cursor->ifa_next;
		}
		freeifaddrs(addrs);
	}
    
	return ipAddr;
}


/**
 *
 * get the wifi address
 *
 */
+ (NSString*)localWifiIPAddress {
	    
	return [UIDevice getCurrentIPAddress:@"en0"];
}

/**
 *
 * get the wifi address info
 *
 */
+ (NSDictionary*)getLocalWifiIPAddressInfo 
{
	BOOL success;
	struct ifaddrs* addrs;
	struct ifaddrs* cursor;
	
    NSMutableDictionary* attrDict = [NSMutableDictionary dictionary];
    
	success = getifaddrs(&addrs) == 0;
	if (success) {
		cursor = addrs;
		while (cursor != NULL) {
			// the second test keeps from picking up the loopback address
			if (cursor->ifa_addr->sa_family == AF_INET 
				&& (cursor->ifa_flags & IFF_LOOPBACK)==0) {
				NSString* name = [NSString stringWithUTF8String: cursor->ifa_name];
				if ([name isEqualToString: @"en0"]) { // Wi-Fi adapter
//                    [attrDict setObject:@"en0" forKey:WIFI_INTERFACE_NAME];
                    
                    char addrBuf[INET_ADDRSTRLEN];
                    
                    memset(addrBuf, 0, sizeof(addrBuf));
                    if (inet_ntop(AF_INET, &((struct sockaddr_in*)cursor->ifa_addr)->sin_addr, addrBuf, (socklen_t)sizeof(addrBuf)) == NULL)
                    {
                        addrBuf[0] = '\0';
                    }
                    NSString* wifiAdd = [NSString stringWithCString:addrBuf encoding:NSUTF8StringEncoding];
                    [attrDict setObject:wifiAdd forKey:WIFI_INTERFACE_ADDR];
                    
                    memset(addrBuf, 0, sizeof(addrBuf));
                    if (inet_ntop(AF_INET, &((struct sockaddr_in*)cursor->ifa_netmask)->sin_addr, addrBuf, (socklen_t)sizeof(addrBuf)) == NULL)
                    {
                        addrBuf[0] = '\0';
                    }
                    NSString* netMask = [NSString stringWithCString:addrBuf encoding:NSUTF8StringEncoding];
                    [attrDict setObject:netMask forKey:WIFI_INTERFACE_NETMASK];
                    
                    memset(addrBuf, 0, sizeof(addrBuf));
                    if (inet_ntop(AF_INET, &((struct sockaddr_in*)cursor->ifa_dstaddr)->sin_addr, addrBuf, (socklen_t)sizeof(addrBuf)) == NULL)
                    {
                        addrBuf[0] = '\0';
                    }
                    NSString* broadcast = [NSString stringWithCString:addrBuf encoding:NSUTF8StringEncoding];
                    [attrDict setObject:broadcast forKey:WIFI_INTERFACE_BROADCAST_ADDR];
                    
//                    [attrDict setObject:
//                            [NSString stringWithUTF8String:
//                                         inet_ntoa(((struct sockaddr_in*)cursor->ifa_addr)->sin_addr)] forKey:WIFI_INTERFACE_ADDR];
//                    [attrDict setObject:[NSString stringWithUTF8String: 
//                                         inet_ntoa(((struct sockaddr_in*)cursor->ifa_netmask)->sin_addr)] forKey:WIFI_INTERFACE_NETMASK];
//                    [attrDict setObject:[NSString stringWithUTF8String: 
//                                         inet_ntoa(((struct sockaddr_in*)cursor->ifa_dstaddr)->sin_addr)] forKey:WIFI_INTERFACE_BROADCAST_ADDR];
					break;
				}
			}
			cursor = cursor->ifa_next;
		}
		freeifaddrs(addrs);
	}
    
	return attrDict;
}


#pragma mark Check Connections

+ (void)pingReachabilityInternal {
	if (!reachability) {
		BOOL ignoresAdHocWiFi = NO; // Thanks to Apple
		struct sockaddr_in ipAddress;
		bzero(&ipAddress, sizeof(ipAddress));
		ipAddress.sin_len = sizeof(ipAddress);
		ipAddress.sin_family = AF_INET;
		ipAddress.sin_addr.s_addr = htonl(ignoresAdHocWiFi ? INADDR_ANY : IN_LINKLOCALNETNUM);
		
		// Recover reachability flags
		reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, 
															  (struct sockaddr*)&ipAddress);
		CFRetain(reachability);
	}
	
	BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(
														  reachability, &connectionFlags);
	
	if (!didRetrieveFlags) {
		printf("Error. Could not recover flags\n");
	}
}

+ (BOOL) networkAvailable {
    [self pingReachabilityInternal];
	BOOL isReachable = ((connectionFlags & kSCNetworkFlagsReachable) != 0);
	BOOL needsConnection = ((connectionFlags & 
							 kSCNetworkFlagsConnectionRequired) != 0);
	return (isReachable && !needsConnection) ? YES : NO;
}

+ (BOOL) activeWWAN {
	if (![self networkAvailable]) {
		return NO;
	}
	return ((connectionFlags & 
			 kSCNetworkReachabilityFlagsIsWWAN) != 0);
}

+ (BOOL) activeWLAN {
	return ([UIDevice localWifiIPAddress] != nil);
}


//
//获取当前接入的wifi的网络名，只有sdk4.1以后才会支持，需要判断
//
+ (NSString*) currentWifiName
{
    NSString *version = [UIDevice currentDevice].systemVersion;
    
    if ([version compare:@"4.1"] == NSOrderedAscending) {
        return nil;
    }
    
    CFArrayRef myArray = CNCopySupportedInterfaces();
    if (nil == myArray) {
        return nil;
    }
    
    CFIndex valueCount = CFArrayGetCount(myArray);
    if (valueCount == 0) {      // 数组为空
        CFRelease(myArray);
        return nil;
    }
    
    CFDictionaryRef myDict = CNCopyCurrentNetworkInfo((CFStringRef)CFArrayGetValueAtIndex(myArray, 0));
    if (myDict == nil) {
        CFRelease(myArray);
        return nil;
    }
    
    CFStringRef networkName = NULL;
    if (CFDictionaryContainsKey(myDict, kCNNetworkInfoKeySSID)) {
        networkName = (CFStringRef)CFDictionaryGetValue(myDict, kCNNetworkInfoKeySSID);
        //CFStringRef bssid = (CFStringRef)CFDictionaryGetValue(myDict, kCNNetworkInfoKeyBSSID);
//        NSLog(@"-----------------------wifi ssid:%@,bssid:%@", networkName, bssid);
    }
    
    CFRelease(myArray);
    
    NSString* result = nil;
    if (NULL == networkName) {
        CFRelease(myDict);
        return result;
    }
    
    result = (__bridge_transfer NSString*)CFRetain(networkName);
    CFRelease(myDict);
    return result;
}

//由于app mac格式特殊，去掉了0，进行补充
+ (NSString*) formatWifiAPMac:(NSString*)aWifiMac
{
    if (aWifiMac == nil) {
        return nil;
    }
    
    NSMutableString* finalMac = [NSMutableString string];
    
    NSArray* array = [aWifiMac componentsSeparatedByString:@":"];
    for (NSUInteger n = 0; n < [array count]; n++) {
        NSString* macByte = [array objectAtIndex:n];
        NSString* finalByte = nil;
        if ([macByte length] == 1) {
            finalByte = [NSString stringWithFormat:@"0%@", macByte];
        }else{
            finalByte = macByte;
        }
        
        if (n + 1 == [array count]) {
            [finalMac appendString:finalByte];
        }else{
            [finalMac appendFormat:@"%@-", finalByte];
        }
    }
    
    return [finalMac lowercaseString];
}

+ (NSString*) currentWifiAPMac
{
    NSString *version = [UIDevice currentDevice].systemVersion;
    
    if ([version compare:@"4.1"] == NSOrderedAscending) {
        return nil;
    }
    
    CFArrayRef myArray = CNCopySupportedInterfaces();
    if (nil == myArray) {
        return nil;
    }
    
    CFDictionaryRef myDict = CNCopyCurrentNetworkInfo((CFStringRef)CFArrayGetValueAtIndex(myArray, 0));
    if (myDict == nil) {
        CFRelease(myArray);
        return nil;
    }
    
    CFStringRef bssid = NULL;
    if (CFDictionaryContainsKey(myDict, kCNNetworkInfoKeyBSSID)) {
        bssid = (CFStringRef)CFDictionaryGetValue(myDict, kCNNetworkInfoKeyBSSID);
    }
    
    CFRelease(myArray);
    
    NSString* result = (__bridge NSString*)bssid;
    CFRelease(myDict);
    if (NULL == bssid || NO == [result isKindOfClass:[NSString class]]) {
        
        return nil;
    }

//    NSLog(@"-----------------------wifi bssid:%@", bssid);
    return [UIDevice formatWifiAPMac:result];
}

// Return the local MAC addy
// Courtesy of FreeBSD hackers email list
// Accidentally munged during previous update. Fixed thanks to mlamb.
+ (NSString *) wifiMacAddr
{
    // 优先尝试从userdefault中读取数据（速度更快）
    NSString *udidStr = nil;
    udidStr = [[NSUserDefaults standardUserDefaults] valueForKey:kKeyChainUDIDKey];
    
    // 做容错处理，对于268版本由于keychain分组配置出错，写入分组出错的问题，补写一次分组
    BOOL hasSetKeyChain = [[[NSUserDefaults standardUserDefaults] valueForKey:@"hasWriteKeyChain"] boolValue];
    if (udidStr && !hasSetKeyChain) {
        [self setUDIDToKeyChain:udidStr];
    }
    
    if (!udidStr) {
        
        // 再尝试从keyChain中读取
        udidStr = [self getUDIDFromKeyChain];
        if (!udidStr || udidStr.length != 17) {       // 如果获取出来的数据不是Mac地址的话，则重新写一次
            
            /*
             * iOS 7.0
             * Starting from iOS 7, the system always returns the value 02:00:00:00:00:00
             * when you ask for the MAC address on any device.
             * use fakeMacAdd + keyChain
             * make sure UDID consistency atfer app delete and reinstall
             */
            if ([[UIDevice currentDevice].systemVersion floatValue] >= 7.0) {
                
                // 使用时间戳等信息构建mac 地址
                long randomID = arc4random();
                long long timeInterval = [[NSDate date] timeIntervalSince1970] * 1000;
                unsigned char *pValue1 = (unsigned char*)&randomID;
                unsigned char *pValue2 = (unsigned char*)&timeInterval;
                
                udidStr = [NSString stringWithFormat:@"%02x-%02x-%02x-%02x-%02x-%02x", pValue1[3], pValue1[2], pValue1[1], pValue2[2], pValue2[1], pValue2[0]];
            }
            else {      // ios 6
                int                    mib[6];
                size_t                len;
                char                *buf;
                unsigned char        *ptr;
                struct if_msghdr    *ifm;
                struct sockaddr_dl    *sdl;
                
                mib[0] = CTL_NET;
                mib[1] = AF_ROUTE;
                mib[2] = 0;
                mib[3] = AF_LINK;
                mib[4] = NET_RT_IFLIST;
                
                if ((mib[5] = if_nametoindex("en0")) == 0) {
                    printf("Error: if_nametoindex error/n");
                    return NULL;
                }
                
                if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
                    printf("Error: sysctl, take 1/n");
                    return NULL;
                }
                
                if ((buf = (char*)malloc(len)) == NULL) {
                    printf("Could not allocate memory. error!/n");
                    return NULL;
                }
                
                if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
                    free(buf);
                    printf("Error: sysctl, take 2");
                    return NULL;
                }
                
                ifm = (struct if_msghdr *)buf;
                sdl = (struct sockaddr_dl *)(ifm + 1);
                ptr = (unsigned char *)LLADDR(sdl);
                NSString *outstring = [NSString stringWithFormat:@"%02x-%02x-%02x-%02x-%02x-%02x", *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
                free(buf);
                udidStr = [outstring lowercaseString];
            }
            
            // 将获取到udid设置到UserDefault中，目的时为了加速，不用每次都来keychain查找
            [[NSUserDefaults standardUserDefaults] setValue:udidStr forKey:kKeyChainUDIDKey];
            
            // 存储到keyChain中
            [self setUDIDToKeyChain:udidStr];
        }
        else {
            // 从keyChain获取到udid后设置到UserDefault中，目的时为了加速，不用每次都来keychain查找
            [[NSUserDefaults standardUserDefaults] setValue:udidStr forKey:kKeyChainUDIDKey];
        }
    }
    
    return udidStr;
}

+ (NSString *)getCurrentPlatform {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = (char *)malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    
    if ([platform isEqualToString:@"iPhone1,1"])    return @"iPhone 1G";
    if ([platform isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([platform isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([platform isEqualToString:@"iPhone3,1"])    return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone3,2"])    return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone3,3"])    return @"Verizon iPhone 4";
    if ([platform isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    if ([platform isEqualToString:@"iPhone5,1"])    return @"iPhone 5 (GSM)";
    if ([platform isEqualToString:@"iPhone5,2"])    return @"iPhone 5 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPhone5,3"])    return @"iPhone 5c (GSM+CDMA)";
    if ([platform isEqualToString:@"iPhone5,4"])    return @"iPhone 5c (UK+Europe+Asis+China)";
    if ([platform isEqualToString:@"iPhone6,1"])    return @"iPhone 5s (GSM+CDMA)";
    if ([platform isEqualToString:@"iPhone6,2"])    return @"iPhone 5s (UK+Europe+Asis+China)";
    
    if ([platform isEqualToString:@"iPod1,1"])      return @"iPod Touch 1G";
    if ([platform isEqualToString:@"iPod2,1"])      return @"iPod Touch 2G";
    if ([platform isEqualToString:@"iPod3,1"])      return @"iPod Touch 3G";
    if ([platform isEqualToString:@"iPod4,1"])      return @"iPod Touch 4G";
    if ([platform isEqualToString:@"iPod5,1"])      return @"iPod Touch 5G";
    
    if ([platform isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([platform isEqualToString:@"iPad2,1"])      return @"iPad 2 (WiFi)";
    if ([platform isEqualToString:@"iPad2,2"])      return @"iPad 2 (GSM)";
    if ([platform isEqualToString:@"iPad2,3"])      return @"iPad 2 (CDMA)";
    if ([platform isEqualToString:@"iPad2,4"])      return @"iPad 2 (WiFi)";
    if ([platform isEqualToString:@"iPad2,5"])      return @"iPad Mini (WIFI)";
    if ([platform isEqualToString:@"iPad2,6"])      return @"iPad Mini (GSM)";
    if ([platform isEqualToString:@"iPad2,7"])      return @"iPad Mini (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad3,1"])      return @"iPad 3 (WiFi)";
    if ([platform isEqualToString:@"iPad3,2"])      return @"iPad 3 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad3,3"])      return @"iPad 3 (CDMA)";
    if ([platform isEqualToString:@"iPad3,4"])      return @"iPad 4 (Wifi)";
    if ([platform isEqualToString:@"iPad3,5"])      return @"iPad 4 (GSM)";
    if ([platform isEqualToString:@"iPad3,6"])      return @"iPad 4 (GSM+CDMA)";
    
    if ([platform isEqualToString:@"i386"])         return @"Simulator";
    if ([platform isEqualToString:@"x86_64"])       return @"Simulator";
    
    return platform;
}


+ (NSString *)getLocalPlatformName
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = (char *)malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);

    return platform;
}



+ (BOOL)isIPhone
{
    NSString* model = [UIDevice currentDevice].model;
    NSRange range = [model rangeOfString:@"iPhone"];
    return (range.location != NSNotFound);
}

+ (BOOL)isIPodTouch
{
    NSString* model = [UIDevice currentDevice].model;
    NSRange range = [model rangeOfString:@"iPod touch"];
    return (range.location != NSNotFound);
}

+ (BOOL)isIPad
{
    NSString* model = [UIDevice currentDevice].model;
    NSRange range = [model rangeOfString:@"iPad"];
    return (range.location != NSNotFound);
}


#pragma mark -
#pragma mark For ios 7 UDID

/*
 * iOS 7.0
 * Starting from iOS 7, the system always returns the value 02:00:00:00:00:00
 * when you ask for the MAC address on any device.
 * use identifierForVendor + keyChain
 * make sure UDID consistency atfer app delete and reinstall
 */
+ (NSString*)_UDID_iOS7
{
    // 优先从userdefault中读取数据（速度更快）
    NSString *outstring = [[NSUserDefaults standardUserDefaults] valueForKey:kKeyChainUDIDKey];
    if (!outstring) {
        outstring = [self getUDIDFromKeyChain];
        
        // 从keyChain获取到outString后设置到UserDefault中，目的时为了加速，不用每次都来keychain查找
        [[NSUserDefaults standardUserDefaults] setValue:outstring forKey:kKeyChainUDIDKey];
        if (!outstring || outstring.length != 17) {       // 如果获取出来的数据不是Mac地址的话，则重新写一次
            
            // 使用时间戳等信息构建mac 地址
            long randomID = random();
            long long timeInterval = [[NSDate date] timeIntervalSince1970] * 1000;
            unsigned char *pValue1 = (unsigned char*)&randomID;
            unsigned char *pValue2 = (unsigned char*)&timeInterval;
            
            outstring = [NSString stringWithFormat:@"%02x-%02x-%02x-%02x-%02x-%02x", pValue1[3], pValue1[2], pValue1[1], pValue2[2], pValue2[1], pValue2[0]];
            [[NSUserDefaults standardUserDefaults] setValue:outstring forKey:kKeyChainUDIDKey];
            [self setUDIDToKeyChain:outstring];
        }
    }
    
    return outstring;
}


#pragma mark -
#pragma mark Helper Method for make identityForVendor consistency

+ (NSString*)getUDIDFromKeyChain
{
    NSMutableDictionary *dictForQuery = [[NSMutableDictionary alloc] init];
    [dictForQuery setValue:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    
    // set Attr Description for query
    [dictForQuery setValue:[NSString stringWithUTF8String:kKeychainUDIDItemIdentifier]   //****
                    forKey:(__bridge NSString *)kSecAttrDescription];                    //原来没有(__bridge NSString *)
    
    // set Attr Identity for query
    NSData *keychainItemID = [NSData dataWithBytes:kKeychainUDIDItemIdentifier
                                            length:strlen(kKeychainUDIDItemIdentifier)];
    [dictForQuery setObject:keychainItemID forKey:(__bridge id)kSecAttrGeneric];
    
    [dictForQuery setValue:(id)kCFBooleanTrue forKey:(__bridge id)kSecMatchCaseInsensitive];
    [dictForQuery setValue:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    [dictForQuery setValue:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    
    OSStatus queryErr   = noErr;
    CFDataRef udidValue = nil;
    NSString *udid      = nil;
    queryErr = SecItemCopyMatching((__bridge CFDictionaryRef)dictForQuery, (CFTypeRef*)&udidValue);

//    CFDictionaryRef *dict = nil;
//    [dictForQuery setValue:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
//    queryErr = SecItemCopyMatching((__bridge CFDictionaryRef)dictForQuery, (CFTypeRef*)&dict);

    if (queryErr == errSecItemNotFound) {
        NSLog(@"KeyChain Item: %@ not found!!!", [NSString stringWithUTF8String:kKeychainUDIDItemIdentifier]);
    }
    else if (queryErr != errSecSuccess) {
        NSLog(@"KeyChain Item query Error!!! Error code:%d", (int)queryErr);
    }
    if (queryErr == errSecSuccess) {
        NSLog(@"KeyChain Item: %@", udidValue);
        
        if (udidValue) {
            udid = [NSString stringWithUTF8String:(const char*)(CFDataGetBytePtr(udidValue))];
        }
    }
    
    return udid;
}

+ (BOOL)setUDIDToKeyChain:(NSString*)udid
{
    NSMutableDictionary *dictForAdd = [[NSMutableDictionary alloc] init];
    
    [dictForAdd setValue:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [dictForAdd setValue:[NSString stringWithUTF8String:kKeychainUDIDItemIdentifier] forKey:(__bridge NSString*)kSecAttrDescription];
    
    [dictForAdd setValue:@"UUID" forKey:(__bridge id)kSecAttrGeneric];
    
    // Default attributes for keychain item.
    [dictForAdd setObject:@"" forKey:(__bridge id)kSecAttrAccount];
    [dictForAdd setObject:@"" forKey:(__bridge id)kSecAttrLabel];
    
    const char *udidStr = [udid UTF8String];
    NSData *keyChainItemValue = [NSData dataWithBytes:udidStr length:strlen(udidStr)];
    [dictForAdd setValue:keyChainItemValue forKey:(__bridge id)kSecValueData];
    
    OSStatus writeErr = noErr;
    if ([self getUDIDFromKeyChain]) {        // there is item in keychain
        [self updateUDIDInKeyChain:udid];
        
        [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:@"hasWriteKeyChain"];
        return YES;
    }
    else {          // add item to keychain
        writeErr = SecItemAdd((__bridge CFDictionaryRef)dictForAdd, NULL);
        if (writeErr != errSecSuccess) {
            NSLog(@"Add KeyChain Item Error!!! Error Code:%d", (int)writeErr);
            
            return NO;
        }
        else {
            NSLog(@"Add KeyChain Item Success!!!");
            
            [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:@"hasWriteKeyChain"];
            return YES;
        }
    }
    
    return NO;
}

+ (BOOL)removeUDIDFromKeyChain
{
    NSMutableDictionary *dictToDelete = [[NSMutableDictionary alloc] init];
    
    [dictToDelete setValue:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    
    NSData *keyChainItemID = [NSData dataWithBytes:kKeychainUDIDItemIdentifier length:strlen(kKeychainUDIDItemIdentifier)];
    [dictToDelete setValue:keyChainItemID forKey:(__bridge id)kSecAttrGeneric];
    
    OSStatus deleteErr = noErr;
    deleteErr = SecItemDelete((__bridge CFDictionaryRef)dictToDelete);
    if (deleteErr != errSecSuccess) {
        NSLog(@"delete UUID from KeyChain Error!!! Error code:%d", (int)deleteErr);
        return NO;
    }
    else {
        NSLog(@"delete success!!!");
    }
    
    return YES;
}

+ (BOOL)updateUDIDInKeyChain:(NSString*)newUDID
{
    
    NSMutableDictionary *dictForQuery = [[NSMutableDictionary alloc] init];
    
    [dictForQuery setValue:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    
    NSData *keychainItemID = [NSData dataWithBytes:kKeychainUDIDItemIdentifier
                                            length:strlen(kKeychainUDIDItemIdentifier)];
    [dictForQuery setValue:keychainItemID forKey:(__bridge id)kSecAttrGeneric];
    [dictForQuery setValue:(id)kCFBooleanTrue forKey:(__bridge id)kSecMatchCaseInsensitive];
    [dictForQuery setValue:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    [dictForQuery setValue:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
    
    CFDictionaryRef queryResult = nil;
    SecItemCopyMatching((__bridge CFDictionaryRef)dictForQuery, (CFTypeRef*)&queryResult);
    if (queryResult) {
        
        NSMutableDictionary *dictForUpdate = [[NSMutableDictionary alloc] init];
        [dictForUpdate setValue:[NSString stringWithUTF8String:kKeychainUDIDItemIdentifier] forKey:(__bridge id)kSecAttrDescription];
        [dictForUpdate setValue:keychainItemID forKey:(__bridge id)kSecAttrGeneric];
        
        const char *udidStr = [newUDID UTF8String];
        NSData *keyChainItemValue = [NSData dataWithBytes:udidStr length:strlen(udidStr)];
        [dictForUpdate setValue:keyChainItemValue forKey:(__bridge id)kSecValueData];
        
        OSStatus updateErr = noErr;
        
        // First we need the attributes from the Keychain.
        NSMutableDictionary *updateItem = [NSMutableDictionary dictionaryWithDictionary:(__bridge NSDictionary*)queryResult];
        
        // Second we need to add the appropriate search key/values.
        // set kSecClass is Very important
        [updateItem setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
        
        updateErr = SecItemUpdate((__bridge CFDictionaryRef)updateItem, (__bridge CFDictionaryRef)dictForUpdate);
        if (updateErr != errSecSuccess) {
            NSLog(@"Update KeyChain Item Error!!! Error Code:%d", (int)updateErr);
            return NO;
        }
        else {
            NSLog(@"Update KeyChain Item Success!!!");
            return YES;
        }
    }

    return NO;
}


@end
