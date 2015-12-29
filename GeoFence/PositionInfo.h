//
//  PositionInfo.h
//  GeoFence
//
//  Created by yanzheng on 15/12/28.
//  Copyright © 2015年 links. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PositionInfo : NSObject

@property (nonatomic) CLLocationDegrees lat;
@property (nonatomic) CLLocationDegrees lng;
@property (nonatomic) NSString *address;
@property (nonatomic) NSUInteger radius;
@property (nonatomic, copy) NSString *identifier;

@end
