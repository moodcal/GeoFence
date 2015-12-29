//
//  TraceRecord.h
//  GeoFence
//
//  Created by yanzheng on 15/12/29.
//  Copyright © 2015年 links. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    TraceRecordTypeEnter,
    TraceRecordTypeExit,
} TraceRecordType;

@interface TraceRecord : NSObject

@property (nonatomic, strong) NSDate *recordAt;
@property (nonatomic) TraceRecordType recordType;
@property (nonatomic, copy) NSString *positionName;
@property (nonatomic, copy) NSString *address;

@end
