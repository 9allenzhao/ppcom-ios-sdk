//
//  PPGetConversationListHttpModel.h
//  PPComLib
//
//  Created by PPMessage on 4/1/16.
//  Copyright © 2016 Yvertical. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PPHttpModel.h"

@class PPSDK;

@interface PPGetConversationListHttpModel : NSObject

+ (instancetype)modelWithClient:(PPSDK*)client;
- (instancetype)initWithClient:(PPSDK*)client;

- (void)getConversationListWithBlock:(PPHttpModelCompletedBlock)block;

@end
