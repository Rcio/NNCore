//
//  NNThreadManager.h
//  NNCore
//
//  Created by Rico 13-7-11.
//  Copyright (c) 2013年 Rcio Wang. All rights reserved.
//

#import <Foundation/Foundation.h>

#define NNSlowQueue [[NNQueueManager sharedManager] queueForName:slowQueueName]
#define NNFastQueue [[NNQueueManager sharedManager] queueForName:fastQueueName]
#define NNNetworkQueue [[NNQueueManager sharedManager] queueForName:networkQueueName]

extern NSString * const slowQueueName;
extern NSString * const fastQueueName;
extern NSString * const networkQueueName;

@interface NNQueueManager : NSObject

+ (NNQueueManager *)sharedManager;

/**
 * queueForName:
 * @brief 根据 queue 名称查询对应的 queue
 * @param queueName queue 名称
 * @return dispatch queue 指针
 */
- (dispatch_queue_t)queueForName:(NSString *)queueName;
- (dispatch_queue_t)createSerialQueueForName:(const NSString *)name;
- (dispatch_queue_t)createConcurrentQueueForName:(const NSString *)name;

@end




BOOL dispatch_current_queue_is_main_queue();
BOOL dispatch_current_queue_is(dispatch_queue_t queue);
void run_block_in_main_queue(dispatch_block_t block);
void run_block_in_main_queue_async(dispatch_block_t block);
void run_block_in_main_queue_after(dispatch_block_t block, float after);
void run_block_in_queue(dispatch_queue_t queue, dispatch_block_t block);
void run_block_in_queue_async(dispatch_queue_t queue, dispatch_block_t block);
