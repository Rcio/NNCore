//
//  NNLogger.m
//  Weiyun
//
//  Created by Rico 12-3-26.
//  Copyright (c) 2012年 Rcio Wang. All rights reserved.
//

#import "NNLogger.h"
#import "NNQueueManager.h"
#import "NNRWLock.h"
#import "NNFileUtils.h"

#define XCODE_COLORS_ESCAPE_MAC @"\033["
#define XCODE_COLORS_ESCAPE_IOS @"\xC2\xA0["

#if 0
#define XCODE_COLORS_ESCAPE  XCODE_COLORS_ESCAPE_IOS
#else
#define XCODE_COLORS_ESCAPE  XCODE_COLORS_ESCAPE_MAC        //在mac上debug的
#endif

#define XCODE_COLORS_RESET_FG  XCODE_COLORS_ESCAPE @"fg;" // Clear any foreground color
#define XCODE_COLORS_RESET_BG  XCODE_COLORS_ESCAPE @"bg;" // Clear any background color
#define XCODE_COLORS_RESET     XCODE_COLORS_ESCAPE @";"   // Clear any foreground or background color

@interface NNLogger()

@property (nonatomic) dispatch_queue_t loggerQueue;
@property (nonatomic) dispatch_source_t loggerSource;

@property (nonatomic) NSMutableArray *dataQueue;
@property (nonatomic) NNRWLock *dataQueueLock;

@property (atomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, assign) NSInteger checkLogCount;

@property (nonatomic) NSDateFormatter *logDatetimeFormatter;

@property (nonatomic) NSString *backupLogFilePath;

- (void)initLogger;

@end

@implementation NNLogger

@synthesize logs;
@synthesize isRelease;
@synthesize fileHandle = _fileHandle;
@synthesize colorEnable = _colorEnable;
@synthesize logLevel = _logLevel;

static NNLogger* sharedLogger = nil;

+ (NNLogger*) sharedLogger
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLogger = [[self alloc] init];
    });

    return sharedLogger;
}

- (id)init
{
    if ((self = [super init]) == nil)
		return nil;
    
    self.logDatetimeFormatter = [[NSDateFormatter alloc] init];
    [self.logDatetimeFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    [self.logDatetimeFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    
    [NNQueueManager sharedManager];
    
    return self;
}

-(void)dealloc
{
    [_fileHandle closeFile];
}

- (void)setLogFilePath:(NSString *)logFilePath {
    assert(logFilePath);
    assert(_logFilePath == nil);
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _logFilePath = logFilePath;
        _backupLogFilePath = [NSString stringWithFormat:@"%@.bak", _logFilePath];
    
        [self initLogger];
    });
}

#pragma mark - W/R Log file
- (void)prepareForLog
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    BOOL isDir = NO;
    if ([fileManager fileExistsAtPath:_logFilePath isDirectory:&isDir] && isDir) {
        [fileManager removeItemAtPath:_logFilePath error:nil];
    }
    
    
    //超过限制大小后，拷贝到backup
    if ([NNFileUtils fileSizeAtPath:_logFilePath] >= LOG_MAX_SIZE) {
        if ([fileManager fileExistsAtPath:_backupLogFilePath]) {
            [fileManager removeItemAtPath:_backupLogFilePath error:nil];
        }
        [fileManager moveItemAtPath:_logFilePath toPath:_backupLogFilePath error:nil];
    }
    
    
    if (![fileManager fileExistsAtPath:_logFilePath]) {
        [fileManager createFileAtPath:_logFilePath contents:nil attributes:nil];
    }
    
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:_logFilePath];
    [self.fileHandle seekToEndOfFile];

    // 创建日志 Queue
    self.dataQueue = [[NSMutableArray alloc] init];
    self.dataQueueLock = [[NNRWLock alloc] init];
    
    self.loggerQueue = [[NNQueueManager sharedManager] createSerialQueueForName:@"NN Logger Queue"];
    self.loggerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0, self.loggerQueue);
    dispatch_source_set_event_handler(self.loggerSource, ^{
        [self writeLogToFile];
    });
    dispatch_resume(self.loggerSource);
}



//该函数不可调用NNLogger打印日志的方法
- (void)checkForLog
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([NNFileUtils fileSizeAtPath:_logFilePath] >= LOG_MAX_SIZE) {
        if ([fileManager fileExistsAtPath:_backupLogFilePath]) {
            [fileManager removeItemAtPath:_backupLogFilePath error:nil];
        }
        [fileManager moveItemAtPath:_logFilePath toPath:_backupLogFilePath error:nil];
    }
    
    if (![fileManager fileExistsAtPath:_logFilePath]) {
        [self.fileHandle closeFile];
        if ([fileManager createFileAtPath:_logFilePath contents:nil attributes:nil]) {
            self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:_logFilePath];
            [self.fileHandle seekToEndOfFile];
        }
    }
}

//该函数不可调用NNLogger打印日志的方法
- (void)saveLog:(NSString *)logStr
{
    [self.dataQueueLock lockWrite];
    [self.dataQueue addObject:logStr];
    [self.dataQueueLock unLockWrite];
    
    dispatch_source_merge_data(self.loggerSource, 1);
}

- (void)writeLogToFile {
    unsigned long count = dispatch_source_get_data(self.loggerSource);
    if (!count) {
        return;
    }
    
    while (1) {
        @autoreleasepool {
            [self.dataQueueLock lockWrite];
            if (self.dataQueue.count == 0) {
                [self.dataQueueLock unLockWrite];
                break;
            }
            
            NSString *logStr = self.dataQueue[0];
            [self.dataQueue removeObjectAtIndex:0];
            [self.dataQueueLock unLockWrite];
            
            if (logStr.length > 5000) {
                logStr = [logStr substringToIndex:5000];
            }
            
            NSString *log = [NSString stringWithFormat:@"%@ : %@", [self timeInCurrentTimeZone], logStr];
            NSData *data = [log dataUsingEncoding:NSUTF8StringEncoding];
            
            // 降低检查日志大小的频率
            _checkLogCount++;
            if (_checkLogCount % 200 == 0) {
                [self checkForLog];
            }
            
            if (self.fileHandle) {
                NSInteger maxTryCount = 2;
                for (NSInteger i = 0; i < maxTryCount; i ++) {
                    @try {
                        [self.fileHandle writeData:data];
                        break;
                    }
                    @catch (NSException *exception) {
                        if (i == (maxTryCount - 1)) {
                            NSLog(@"写日志失败了，%@", exception);
                        }
                    }
                }
            }
            else {
                NSLog(@"checkForLog: nil == self.fileHandle");
            }
        }
    }
    
    [self.fileHandle synchronizeFile];
}

/*
 *日志初始化
 */
-(void)initLogger
{
    @autoreleasepool {
        
        logs = [[NSMutableArray alloc] init];
     
        //默认为debug版，需要打印日志
#if __OPTIMIZE__
        self.isRelease = YES;
        _logLevel = (NN_LOG_LEVEL_WARNNING | NN_LOG_LEVEL_ERROR | NN_LOG_LEVEL_INFO);
#else
        self.isRelease = NO;
        _logLevel = (NN_LOG_LEVEL_VERBOSE | NN_LOG_LEVEL_DEBUG | NN_LOG_LEVEL_INFO | NN_LOG_LEVEL_WARNNING | NN_LOG_LEVEL_ERROR);
#endif
        _colorEnable = YES;
        [self prepareForLog];
    }
}

-(NSString*)getLevelStr:(NN_LOG_LEVEL)aLevel
{
    NSString* result = nil;
    switch (aLevel) {
        case NN_LOG_LEVEL_NONE:
            result = @"NONE";
            break;
        
        case NN_LOG_LEVEL_VERBOSE:
            result = @"VERBOSE";
            break;
        
        case NN_LOG_LEVEL_DEBUG:
            result = @"DEBUG";
            break;
            
        case NN_LOG_LEVEL_INFO:
            result = @"INFO";
            break;
            
        case NN_LOG_LEVEL_WARNNING:
            result = @"WARNNING";
            break;
            
        case NN_LOG_LEVEL_ERROR:
            result = @"ERROR";
            break;
            
        default:
            break;
    }
    
    return result;
}



#pragma mark - Log Color



- (BOOL)isXcodeColorEnable
{
#ifdef __OPTIMIZE__
    return NO;
#else
    
    static BOOL isXcodeColorEnable__ = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
//        setenv("XcodeColors", "YES", 0);
        char *xcode_colors = getenv("XcodeColors");
        if (xcode_colors && (strcmp(xcode_colors, "YES") == 0))
        {
            isXcodeColorEnable__ = YES;
        }
    });
    
    return (isXcodeColorEnable__ && self.colorEnable);
#endif
}



-(NSString*)colorDescOfLevel:(NN_LOG_LEVEL)aLevel
{
    NSString* result = nil;
    switch (aLevel) {
        case NN_LOG_LEVEL_NONE:
            result = @"fg0,0,0;";
            break;
            
        case NN_LOG_LEVEL_VERBOSE:
            result = @"fg0,0,0;";
            break;
            
        case NN_LOG_LEVEL_DEBUG:
            result = @"fg0,0,245;";
            break;
            
        case NN_LOG_LEVEL_INFO:
            result = @"fg0,0,0;";
            break;
            
        case NN_LOG_LEVEL_WARNNING:
            result = @"fg255,102,0;";
            break;
            
        case NN_LOG_LEVEL_ERROR:
            result = @"fg255,0,0;";
            break;
            
        default:
            break;
    }
    
    return result;
}



#pragma mark - Log

- (void)log:(NSString*)tag level:(NN_LOG_LEVEL)aLevel content:(NSString*)aContent misc:(NSString*)aMisc
{
    assert(self.logFilePath);
    
    if (NN_LOG_LEVEL_NONE == aLevel) {
        return;
    }
    
    if (aLevel != (_logLevel & aLevel)) {
        return;
    }
    
    NSString *logStr = [NSString stringWithFormat:@"[%@:%@] [%@]%@\n", tag, [self getLevelStr:aLevel], aMisc, aContent];
        
    //保存Log
    if (!dispatch_current_queue_is_main_queue()) {
        run_block_in_queue_async(NNFastQueue, ^{
            [self saveLog:logStr];
        });
    } else {
        [self saveLog:logStr];
    }
    
    if (YES == self.isRelease) {
        return;
    }
    
#ifdef DEBUG
    NSLog(@"%@", logStr);
#endif
}

- (void)verbose:(NSString*)tag  misc:(NSString*)aMisc format:(NSString*)aFormat, ...
{
    va_list argumentList;
    
    if (nil == aFormat) {
        return;
    }
    
    va_start(argumentList, aFormat);
    NSString *content = [[NSString alloc] initWithFormat:aFormat arguments:argumentList];
    va_end(argumentList);
    
    
    [self log:tag level:NN_LOG_LEVEL_VERBOSE content:content misc:aMisc];
}


- (void)debug:(NSString*)tag  misc:(NSString*)aMisc format:(NSString*)aFormat, ...
{
    va_list argumentList;
    
    if (nil == aFormat) {
        return;
    }
    
    va_start(argumentList, aFormat);
    NSString *content = [[NSString alloc] initWithFormat:aFormat arguments:argumentList];
    va_end(argumentList);
    
    
    [self log:tag level:NN_LOG_LEVEL_DEBUG content:content misc:aMisc];
}


- (void)info:(NSString*)tag  misc:(NSString*)aMisc format:(NSString*)aFormat, ...
{
    va_list argumentList;
    
    if (nil == aFormat) {
        return;
    }
    
    va_start(argumentList, aFormat);
    NSString *content = [[NSString alloc] initWithFormat:aFormat arguments:argumentList];
    va_end(argumentList);
    
    
    [self log:tag level:NN_LOG_LEVEL_INFO content:content misc:aMisc];
}

- (void)warnning:(NSString*)tag  misc:(NSString*)aMisc format:(NSString*)aFormat, ...
{
    va_list argumentList;
    
    if (nil == aFormat) {
        return;
    }
    
    va_start(argumentList, aFormat);
    NSString *content = [[NSString alloc] initWithFormat:aFormat arguments:argumentList];
    va_end(argumentList);

    
    [self log:tag level:NN_LOG_LEVEL_WARNNING content:content misc:aMisc];
}

- (void)error:(NSString*)tag  misc:(NSString*)aMisc format:(NSString*)aFormat, ...
{
    va_list argumentList;
    
    if (nil == aFormat) {
        return;
    }
    
    va_start(argumentList, aFormat);
    NSString *content = [[NSString alloc] initWithFormat:aFormat arguments:argumentList];
    va_end(argumentList);
    
    [self log:tag level:NN_LOG_LEVEL_ERROR content:content misc:aMisc];
}

- (void)verbose:(NSString *)tag misc:(NSString *)aMisc log:(NSString *)logStr {
    [self log:tag level:NN_LOG_LEVEL_VERBOSE content:logStr misc:aMisc];
}

- (void)debug:(NSString *)tag misc:(NSString *)aMisc log:(NSString *)logStr {
    [self log:tag level:NN_LOG_LEVEL_DEBUG content:logStr misc:aMisc];
}

- (void)info:(NSString *)tag misc:(NSString *)aMisc log:(NSString *)logStr {
    [self log:tag level:NN_LOG_LEVEL_INFO content:logStr misc:aMisc];
}

- (void)warning:(NSString *)tag misc:(NSString *)aMisc log:(NSString *)logStr {
    [self log:tag level:NN_LOG_LEVEL_WARNNING content:logStr misc:aMisc];
}

- (void)error:(NSString *)tag misc:(NSString *)aMisc log:(NSString *)logStr {
    [self log:tag level:NN_LOG_LEVEL_ERROR content:logStr misc:aMisc];
}

#pragma mark - Helper

- (NSString *)timeInCurrentTimeZone
{
    NSDate *nowDate = [NSDate date];

    NSString * dateStr = [self.logDatetimeFormatter stringFromDate:nowDate];
    return dateStr;
}

@end



