//
//  NNLogger.h
//  Weiyun
//
//  Created by Rico 12-3-26.
//  Copyright (c) 2012年 Rcio Wang. All rights reserved.
//

#import <Foundation/Foundation.h>

#define LOG_MAX_SIZE       (1024 * 1024 * 3)  //6M

#define LOG_CACHE_NUM       50   //缓存50条日志，满了一次写入
#define LOG_MAX_SAVE_INTERVAL   10   //每隔10s写一次日志

typedef NS_ENUM(NSInteger, NN_LOG_LEVEL) {
    NN_LOG_LEVEL_NONE                    = 0x00000000,   //none,不写任何日志
    NN_LOG_LEVEL_VERBOSE                 = 0x00000001,   //verbose
    NN_LOG_LEVEL_DEBUG                   = 0x00000002,   //debug
    NN_LOG_LEVEL_INFO                    = 0x00000004,   //info
    NN_LOG_LEVEL_WARNNING                = 0x00000008,   //warnning
    NN_LOG_LEVEL_ERROR                   = 0x00000010,   //error
};

/*
 *日志行信息
 */
@interface NNLogModulInfo : NSObject
{
    NSString*           content;
    
}

@property (nonatomic, strong)   NSString*           moduleName;

@end

/*
 *日志
 */
@interface NNLogger : NSObject
{
    NSMutableArray*             logs;
    BOOL                        isRelease;      //release版本不记录任何日志
    NSFileHandle *              _fileHandle;
    BOOL                        _colorEnable;
    NN_LOG_LEVEL             logLevel;
}

@property (nonatomic, copy)   NSString *logFilePath;
@property (nonatomic, strong) NSMutableArray*        logs;
@property (nonatomic, assign) BOOL                   isRelease;
@property (nonatomic, assign) NN_LOG_LEVEL        logLevel;
@property (nonatomic, assign) BOOL                  colorEnable;            //是否使用颜色

+ (NNLogger *)sharedLogger;

- (void)verbose:(NSString*)tag misc:(NSString*)aMisc format:(NSString*)aFormat;
- (void)debug:(NSString*)tag misc:(NSString*)aMisc format:(NSString*)aFormat, ... NS_FORMAT_FUNCTION(3, 4);
- (void)info:(NSString*)tag misc:(NSString*)aMisc format:(NSString*)aFormat, ... NS_FORMAT_FUNCTION(3, 4);
- (void)warnning:(NSString*)tag misc:(NSString*)aMisc format:(NSString*)aFormat, ... NS_FORMAT_FUNCTION(3, 4);
- (void)error:(NSString*)tag misc:(NSString*)aMisc format:(NSString*)aFormat, ... NS_FORMAT_FUNCTION(3, 4);

// Methods for swift

- (void)verbose:(NSString*)tag misc:(NSString*)aMisc log:(NSString*)logStr;
- (void)debug:(NSString*)tag misc:(NSString*)aMisc log:(NSString*)logStr;
- (void)info:(NSString*)tag misc:(NSString*)aMisc log:(NSString*)logStr;
- (void)warning:(NSString*)tag misc:(NSString*)aMisc log:(NSString*)logStr;
- (void)error:(NSString*)tag misc:(NSString*)aMisc log:(NSString*)logStr;

@end

#define NNLogGetMiscInfo()   [NSString stringWithFormat:@"%@:%d %s", [[[NSString stringWithFormat:@"%s", __FILE__] componentsSeparatedByString:@"/"] lastObject], __LINE__, __FUNCTION__]

#define NNLogVerbose(module, formatString,...) [[NNLogger sharedLogger] verbose:module misc:(NNLogGetMiscInfo()) format:formatString, ##__VA_ARGS__]

#define NNLogDebug(module, formatString,...) [[NNLogger sharedLogger] debug:module misc:(NNLogGetMiscInfo()) format:formatString, ##__VA_ARGS__]

#define NNLogInfo(module, formatString,...) [[NNLogger sharedLogger] info:module  misc:(NNLogGetMiscInfo()) format:formatString, ##__VA_ARGS__]

#define NNLogWarning(module, formatString,...) [[NNLogger sharedLogger] warnning:module misc:(NNLogGetMiscInfo()) format:formatString, ##__VA_ARGS__]

#define NNLogError(module, formatString,...) [[NNLogger sharedLogger] error:module misc:(NNLogGetMiscInfo()) format:formatString, ##__VA_ARGS__]

