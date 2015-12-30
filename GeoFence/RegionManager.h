//
//  RegionManager.h
//  GeoFence
//
//  Created by yanzheng on 15/12/30.
//  Copyright © 2015年 links. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PositionInfo.h"
#import "TraceRecord.h"

@protocol RegionManagerDelegate <NSObject>
- (void)locationDidUpdated:(CLLocationCoordinate2D)coordinate;
- (void)positionGeoUpdated:(PositionInfo *)positionInfo;
@end

@interface RegionManager : NSObject <CLLocationManagerDelegate>

@property (strong, nonatomic) NSMutableArray *positions;
@property (strong, nonatomic) NSMutableArray *records;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLGeocoder *geocoder;
@property (weak, nonatomic) id<RegionManagerDelegate> delegate;

+ (RegionManager *)sharedInstance;
- (instancetype)init;

- (void)addMonitorForPosition:(PositionInfo *)positionInfo;
- (void)addPositionInfo:(PositionInfo *)positionInfo;
- (void)syncPositions;
- (void)syncRecords;
- (void)geoOnebyOne;
- (BOOL)isValidPosition:(PositionInfo *)positionInfo;
- (CLCircularRegion *)regionWithId:(NSString *)identifier;
- (void)asyncGeoForPosition:(PositionInfo *)positionInfo;
- (void)monitorAllPositions;

@end
