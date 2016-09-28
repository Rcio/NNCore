//
//  NNQueueManager.m
//  NNCore
//
//  Created by Rico 13-7-11.
//  Copyright (c) 2013年 Rcio Wang. All rights reserved.
//

#import "NNQueueManager.h"

NSString * const mainQueueName = @"__mainQueue__";

NSString * const slowQueueName = @"__slowQueue__";
NSString * const fastQueueName = @"__fastQueue__";

NSString * const networkQueueName = @"__networkQueue__";

static void *queueNameKey = (__bridge void *)@"queuNameKey";

@interface NNQueueManager ()
@property (nonatomic, strong) NSMutableDictionary *customQueueCache;

@end

@implementation NNQueueManager
+ (NNQueueManager *)sharedManager
{
    static NNQueueManager *_sharedManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[[self class] alloc] init];
    });
    
    return _sharedManager;
}

- (id)init {
    self = [super init];
    
    _customQueueCache = [[NSMutableDictionary alloc] init];

    NSArray *customQueueNames = @[slowQueueName,
                                  fastQueueName,
                                  networkQueueName];
    
    for (NSString *queueName in customQueueNames) {
        // 创建
        dispatch_queue_t customQueue = dispatch_queue_create(queueName.UTF8String, NULL);
        // 设置标志变量
        dispatch_queue_set_specific(customQueue, queueNameKey, (__bridge void *)(queueName), NULL);
        // 添加缓存
        [_customQueueCache setObject:customQueue forKey:queueName];
    }
    
    dispatch_queue_set_specific(dispatch_get_main_queue(), queueNameKey, (__bridge void *)(mainQueueName), NULL);

    return self;
}

#pragma mark API
- (dispatch_queue_t)queueForName:(NSString *)queueName {
    assert(queueName);
    
    return [_customQueueCache objectForKey:queueName];
}

- (dispatch_queue_t)createSerialQueueForName:(const NSString *)name {
    dispatch_queue_t customQueue = dispatch_queue_create(name.UTF8String, NULL);
    dispatch_queue_set_specific(customQueue, queueNameKey, (__bridge void *)(name), NULL);
    return customQueue;
}

- (dispatch_queue_t)createConcurrentQueueForName:(const NSString *)name {
    dispatch_queue_t customQueue = dispatch_queue_create(name.UTF8String, DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_set_specific(customQueue, queueNameKey, (__bridge void *)(name), NULL);
    return customQueue;
}

@end


// C Function
static inline BOOL is_same_queue(dispatch_queue_t queue) {
    if (dispatch_get_specific(queueNameKey)
        == dispatch_queue_get_specific(queue, queueNameKey)) {
        return YES;
    }
    else {
        return NO;
    }
}


BOOL dispatch_current_queue_is_main_queue() {
    return is_same_queue(dispatch_get_main_queue());
}

BOOL dispatch_current_queue_is(dispatch_queue_t queue) {
    return is_same_queue(queue);
}

void run_block_in_main_queue(dispatch_block_t block) {
    if (dispatch_current_queue_is_main_queue()) {
        block();
    }
    else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

void run_block_in_main_queue_async(dispatch_block_t block) {
    dispatch_async(dispatch_get_main_queue(), block);
}

void run_block_in_main_queue_after(dispatch_block_t block, float after) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(after * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

void run_block_in_queue(dispatch_queue_t queue, dispatch_block_t block) {
    if (is_same_queue(queue)) {
        block();
    }
    else {
        dispatch_sync(queue, block);
    }
}

void run_block_in_queue_async(dispatch_queue_t queue, dispatch_block_t block) {
    dispatch_async(queue, block);
}