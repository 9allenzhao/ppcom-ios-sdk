//
//  PPSDK.m
//  PPMessage
//
//  Created by PPMessage on 2/4/16.
//  Copyright © 2016 PPMessage. All rights reserved.
//

#import "PPSDK.h"
#import "PPAPI.h"
#import "PPWebSocketPool.h"
#import "PPReceiver.h"
#import "PPSDKStartUpHelper.h"

#import "PPStoreManager.h"
#import "PPMessagesStore.h"

#import "PPLog.h"

// Notification: A new message arrived
NSString *const PPSDKMessageArrived = @"PPSDKMessageArrived";

// Notification: Message send succeed
NSString *const PPSDKMessageSendSucceed = @"PPSDKMessageSendSucceed";

// Notification: Message send failed
NSString *const PPSDKMessageSendFailed = @"PPSDKMessageSendFailed";

@interface PPSDK () <PPWebSocketPoolDelegate, PPSDKStartUpHelperDelegate>

@property (nonatomic, readwrite) PPSDKConfiguration* configuration;
@property (nonatomic) PPSDKStartUpHelper* startUpHelper;

@property (nonatomic) PPStoreManager *storeManager;
@property (nonatomic) PPMessagesStore *messagesStore;

@end

@implementation PPSDK

+ (instancetype)sharedSDK {
    static PPSDK *sharedSDK = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedSDK = [[self alloc] init];
    });
    return sharedSDK;
}

// ==============================
// Developer API
// ==============================

- (void)configure:(PPSDKConfiguration*)configuration {
    self.configuration = configuration;
}

- (void)start {
    if ([self.startUpHelper started] || [self.startUpHelper starting]) return;
    [self.startUpHelper start];
}

- (void)reset {
    if (_webSocket) {
        [_webSocket close];
    }
    if (_user) {
        _user = nil;
    }
    if (_app) {
        _app = nil;
    }
}

- (BOOL)isStarted {
    return [self.startUpHelper started];
}

- (BOOL)isStarting {
    return [self.startUpHelper starting];
}

// ==============================
// Getter
// ==============================

- (PPAPI*)api {
    if (!_api) {
        _api = [[PPAPI alloc] initWithSDK: self];
    }
    return _api;
}

- (PPWebSocketPool*)webSocket {
    if (!_webSocket) {
        _webSocket = [[PPWebSocketPool alloc] initWithPPSDK:self];
    }
    return _webSocket;
}

- (PPSDKStartUpHelper*)startUpHelper {
    if (!_startUpHelper) {
        _startUpHelper = [[PPSDKStartUpHelper alloc] initWithSDK:self];
        _startUpHelper.startUpDelegate = self;
    }
    return _startUpHelper;
}

- (PPStoreManager*)storeManager {
    if (!_storeManager) {
        _storeManager = [PPStoreManager instanceWithClient:self];
    }
    return _storeManager;
}

- (PPMessagesStore*)messagesStore {
    if (!_messagesStore) {
        _messagesStore = self.storeManager.messagesStore;
    }
    return _messagesStore;
}

// ==============================
// Application Lifecycle
// ==============================

- (void)applicationEnterForeground:(UIApplication *)application {
    
}

- (void)applicationEnterBackground:(UIApplication *)application {
    
}

// ==============================
// PPWebSocketPoolDelegate
// ==============================

- (void)didMessageArrived:(PPWebSocketPool *)webSocket message:(id)obj {
    [[PPReceiver sharedReceiver] handle:obj handleCompleted:^(id obj, PPReceiverMessageType type, BOOL success) {
        if (!success) {
            PPFastLog(@"[PPSDK] PPReciver receive webSocket message:%@, but parse it failed, ignore this message.", obj);
            return;
        }
        
        switch (type) {
            case PPReceiverMessageTypeMsg:
                [self didPPMessageArrived:obj];
                break;
                
            case PPReceiverMessageTypeSendAck:
                [self didSendAckMessageArrived:obj];
                break;
                
            case PPReceiverMessageTypeLogout:
                break;
                
            case PPReceiverMessageTypeUnknown:
                break;
                
            default:
                break;
        }
    }];
}

- (void)didPPMessageArrived:(id)obj {
    PPMessage *message = obj;
    [self.messagesStore updateWithNewMessage:message];
    [self postWebSocketMessageNotificationWithObject:obj forName:PPSDKMessageArrived];
}

- (void)didSendAckMessageArrived:(id)obj {
    NSDictionary *notifyObj = obj;
    NSString *conversationUUID = notifyObj[@"conversation_uuid"];
    NSString *messageUUID = notifyObj[@"message_uuid"];
    
    if ([notifyObj[@"error_code"] integerValue] != 0) {
        [self.messagesStore updateMessageStatus:PPMessageStatusError messageIndentifier:messageUUID conversationUUID:conversationUUID];
        [self postWebSocketMessageNotificationWithObject:obj forName:PPSDKMessageSendFailed];
    } else {
        [self.messagesStore updateMessageStatus:PPMessageStatusOk messageIndentifier:messageUUID conversationUUID:conversationUUID];
        [self postWebSocketMessageNotificationWithObject:obj forName:PPSDKMessageSendSucceed];
    }
}

// After update inner data states, we will post this websocket message as a Notification.
// You can receive these Notification in the `UIViewController` to update view
// And don't forget to removeObserver when the `UIViewController` become invisible
- (void)postWebSocketMessageNotificationWithObject:(id)object
                                           forName:(NSString*)notificationName {
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:object];
}

// ==============================
// PPSDKStartUpHelperDelegate
// ==============================
- (void)didSDKStartUpSucceded:(PPSDKStartUpHelper*)startUpHelper {
    [self notifyStartUpSucceded];
}

- (void)didSDKStartUpFailed:(PPSDKStartUpHelper*)startUpHelper errorInfo:(id)errorInfo {
    [self notifyStartUpFailedWithErrorInfo:errorInfo];
}

// ==============================
// PPSDKDelegate
// ==============================
- (void)notifyStartUpSucceded {
    if (self.sdkDelegate) {
        if ([self.sdkDelegate respondsToSelector:@selector(didPPSDKStartUpSucceded:)]) {
            [self.sdkDelegate didPPSDKStartUpSucceded:self];
        }
    }
}

- (void)notifyStartUpFailedWithErrorInfo:(id)errorInfo {
    if (self.sdkDelegate) {
        if ([self.sdkDelegate respondsToSelector:@selector(didPPSDKStartUpFailed:errorInfo:)]) {
            [self.sdkDelegate didPPSDKStartUpFailed:self errorInfo:errorInfo];
        }
    }
}

// TODO: report websocket state

//- (void)didSocketOpened:(PPWebSocketPool *)webSocket {
//    if (self.webSocketStateChangeDelegate &&
//        [self.webSocketStateChangeDelegate respondsToSelector:@selector(didWebSocketStateChanged:)]) {
//        [self.webSocketStateChangeDelegate didWebSocketStateChanged:PPWebSocketStateOpen];
//    }
//    self.webSocketState = PPWebSocketStateOpen;
//    
//    [self fetchUnackedMessages];
//}
//
//- (void)didSocketMeetError:(PPWebSocketPool *)webSocket error:(NSError *)error {
//    if (self.webSocketStateChangeDelegate &&
//        [self.webSocketStateChangeDelegate respondsToSelector:@selector(didWebSocketStateChanged:)]) {
//        [self.webSocketStateChangeDelegate didWebSocketStateChanged:PPWebSocketStateClosed];
//    }
//    self.webSocketState = PPWebSocketStateClosed;
//}
//
//- (void)didSocketClosed:(PPWebSocketPool *)webSocket {
//    if (self.webSocketStateChangeDelegate &&
//        [self.webSocketStateChangeDelegate respondsToSelector:@selector(didWebSocketStateChanged:)]) {
//        [self.webSocketStateChangeDelegate didWebSocketStateChanged:PPWebSocketStateClosed];
//    }
//    self.webSocketState = PPWebSocketStateClosed;
//}
//
//- (void)didSocketConnecting:(PPWebSocketPool *)webSocket {
//    if (self.webSocketStateChangeDelegate &&
//        [self.webSocketStateChangeDelegate respondsToSelector:@selector(didWebSocketStateChanged:)]) {
//        [self.webSocketStateChangeDelegate didWebSocketStateChanged:PPWebSocketStateConnecting];
//    }
//    self.webSocketState = PPWebSocketStateConnecting;
//}

@end