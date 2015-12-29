//
//  LocationTransform.h
//  GeoFence
//
//  Created by yanzheng on 15/12/29.
//  Copyright © 2015年 links. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LocationTransform : NSObject

+ (CLLocationCoordinate2D)gmapLocForGps:(CLLocationCoordinate2D)gpsCoordinate;
+ (CLLocationCoordinate2D)gpsForGmapLoc:(CLLocationCoordinate2D)gmapCoordinate;

@end
