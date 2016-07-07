//
//  PPFetchUnackedMessagesJob.m
//  PPMessage
//
//  Created by PPMessage on 3/10/16.
//  Copyright © 2016 PPMessage. All rights reserved.
//

#import "PPFetchUnackedMessagesTask.h"

#import "PPSDK.h"
#import "PPServiceUser.h"
#import "PPAPI.h"
#import "PPWebSocketPool.h"

#import "PPSDKUtils.h"
#import "PPLog.h"
#import "PPMessageUtils.h"

#import "PPGetUserDetailInfoHttpModel.h"
#import "PPGetUnackedMessagesHttpModel.h"

#import "PPStoreManager.h"
#import "PPUsersStore.h"

static const NSTimeInterval PPGetUnackedMessageDelayTime = 0.5;

@interface PPFetchUnackedMessagesTask ()

@property NSUInteger unackedMessagesIndex;
@property BOOL cancelled;
@property (nonatomic) NSMutableArray *unackedMessagesArray;
@property (nonatomic) NSTimer *timer;

@property (nonatomic) PPSDK *sdk;
@property (nonatomic) PPUsersStore *usersStore;

@end

@implementation PPFetchUnackedMessagesTask

- (instancetype)initWithSDK:(PPSDK *)sdk {
    if (self = [super init]) {
        self.sdk = sdk;
        self.unackedMessagesIndex = 0;
        self.cancelled = NO;
    }
    return self;
}

- (void)run {
    [self receiveUnackedMessages];
}

- (void)cancel {
    self.cancelled = YES;
    [self stopTimer];
}

#pragma mark - NSTimer Event

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:PPGetUnackedMessageDelayTime
                                                  target:self
                                                selector:@selector(messageArrived:)
                                                userInfo:nil
                                                 repeats:YES];
    [self.timer fire];
}

- (void)stopTimer {
    if (self.timer && [self.timer isValid]) {
        [self.timer invalidate];
    }
}

// ======================================
// Get unacked messages, Parse messages
// ======================================

- (void)receiveUnackedMessages {
    PPFastLog(@"[PPFetchUnackedMessagesTask] receive unacked messages");
    PPGetUnackedMessagesHttpModel *getUnackedMessagesHttpModel = [[PPGetUnackedMessagesHttpModel alloc] initWithSDK:self.sdk];
    [getUnackedMessagesHttpModel getUnackeMessagesWithBlock:^(id obj, NSDictionary *response, NSError *error) {
        if (obj) {
            self.unackedMessagesArray = obj;
            [self startTimer];
        }
        NSUInteger count = self.unackedMessagesArray ? [self.unackedMessagesArray count] : 0;
        PPFastLog(@"[PPFetchUnackedMessagesTask] receive %@ unacked messages", [NSNumber numberWithUnsignedInteger:count]);
    }];
}

- (void)addFromUserForMessageDictionary:(NSMutableDictionary*)msgContainer
                              completed:(void (^)(NSMutableDictionary *msg))completed {
    NSMutableDictionary *msg = msgContainer[@"msg"];
    NSString *userUUID = msg[@"fi"];
    [self.usersStore findWithUserUUID:userUUID withBlock:^(PPUser *user) {
        if (user) {
            // Build a from_user dictionary
            NSMutableDictionary *fromUserDictionary = [NSMutableDictionary dictionary];
            fromUserDictionary[@"user_fullname"] = user.userName;
            fromUserDictionary[@"uuid"] = user.userUuid;
            fromUserDictionary[@"user_email"] = user.userEmail;
            fromUserDictionary[@"user_icon"] = user.userIcon;
            msg[@"from_user"] = fromUserDictionary;
        }
        if (completed) completed(msgContainer);
    }];
}

- (void)messageArrived:(id)userInfo {
    if (self.cancelled ||
        !self.unackedMessagesArray ||
        self.unackedMessagesArray.count == 0 ||
        self.unackedMessagesIndex >= self.unackedMessagesArray.count) {
        PPFastLog(@"[PPFetchUnackedMessagesTask] cancelled, index:%@, total count:%@",
                  @(self.unackedMessagesIndex),
                  @(self.unackedMessagesArray ? self.unackedMessagesArray.count : 0));
        [self stopTimer];
        return;
    }
    
    NSMutableDictionary *msg = self.unackedMessagesArray[self.unackedMessagesIndex++];
    [self addFromUserForMessageDictionary:msg completed:^(NSMutableDictionary *msg) {
    
        [self simulateArrivedWebSocketMessage:msg];
        
    }];
}

- (void)simulateArrivedWebSocketMessage:(NSMutableDictionary*)msg {
    PPWebSocketPool *webSocket = [PPSDK sharedSDK].webSocket;
    id<PPWebSocketPoolDelegate> webSocketDelegate = webSocket.webSocketPoolDelegate;
    if (webSocketDelegate) {
        [webSocketDelegate didMessageArrived:webSocket message:[self convertToWebSocketMessageWithMsg:msg]];
    }
}

- (NSString*)convertToWebSocketMessageWithMsg:(NSMutableDictionary*)msg {
    NSDictionary *webSocketMsg = @{ @"type":@"MSG",
                                    @"msg":msg };
    return PPDictionaryToJsonString(webSocketMsg);
}

// =======================
// Getter
// =======================
- (PPUsersStore*)usersStore {
    if (!_usersStore) {
        _usersStore = [PPStoreManager instanceWithClient:self.sdk].usersStore;
    }
    return _usersStore;
}

// =======================
// TEST DATA
// =======================

#pragma mark - Test Data {

- (NSDictionary*)buildUnackedMessages:(NSUInteger)count {
    
    NSDictionary *singleMessage = @{ @"ci":@"7f86ee70-3069-11e6-811e-02287b8c0ebf",
                                            @"ft":@"DU",
                                            @"tt":@"AP",
                                            @"bo":@"SDF",
                                            @"ts":@(1465714439.74822),
                                            @"mt":@"NOTI",
                                            @"tl":@"",
                                            @"ms":@"TEXT",
                                            @"ti":@"7f86ee70-3069-11e6-811e-02287b8c0ebf",
                                            @"fi":@"7d20ff2c-3069-11e6-8f02-02287b8c0ebf",
                                            @"id":@"24b338e2-6f95-486b-b1c5-28e3547c77d6",
                                            @"ct":@"P2S"
                                            };
    NSString *singleMessageString = PPDictionaryToJsonString(singleMessage);
    NSMutableArray *listArray = [NSMutableArray arrayWithCapacity:count];
    for (int i=0; i < count; ++i) {
        [listArray addObject:PPRandomUUID()];
    }
    
    NSMutableDictionary *messageDictionary = [NSMutableDictionary dictionaryWithCapacity:count];
    for (int i=0; i < count; ++i) {
        [messageDictionary setObject:singleMessageString forKey:[listArray objectAtIndex:i]];
    }
    
    return @{
             @"error_code":@(0),
             @"error_string":@"success",
             @"list":listArray,
             @"message":messageDictionary,
             @"size":@(count),
             @"uri":@"/GET_UNACKED_MESSAGES"
             };
}

@end
