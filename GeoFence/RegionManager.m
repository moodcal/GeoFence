//
//  RegionManager.m
//  GeoFence
//
//  Created by yanzheng on 15/12/30.
//  Copyright © 2015年 links. All rights reserved.
//

#import "RegionManager.h"

@implementation RegionManager

+ (RegionManager *)sharedInstance
{
    static dispatch_once_t pred;
    static RegionManager *sharedInstance = nil;
    dispatch_once(&pred, ^{
        sharedInstance = [[RegionManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        [self.locationManager requestAlwaysAuthorization];
        [self.locationManager startUpdatingLocation];

        self.geocoder = [[CLGeocoder alloc] init];

        NSString *positionJsonStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"StoredPositions"];
        self.positions = [[NSArray yy_modelArrayWithClass:[PositionInfo class] json:positionJsonStr] mutableCopy];
        if (!self.positions) self.positions = [NSMutableArray array];
        
        NSString *recordJsonStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"StoredRecords"];
        self.records = [[NSArray yy_modelArrayWithClass:[TraceRecord class] json:recordJsonStr] mutableCopy];
        if (!self.records) self.records = [NSMutableArray array];
        
        for (CLCircularRegion *region in self.locationManager.monitoredRegions) {
            NSLog(@"monitored region: %@, %.4f, %.4f, %.0f", region.identifier, region.center.latitude, region.center.longitude, region.radius);
        }
    }
    return self;
}

#pragma mark - LocationManager Delegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    for (CLLocation *location in locations) {
        if ([location.timestamp timeIntervalSinceNow] > -30.0) {
            if ([self.delegate respondsToSelector:@selector(locationDidUpdated:)])
                [self.delegate locationDidUpdated:location.coordinate];
            [self.locationManager stopUpdatingLocation];
            return;
        }
    }
}

-(void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    TraceRecord *record = [TraceRecord new];
    record.recordAt = [NSDate date];
    record.recordType = TraceRecordTypeEnter;
    record.positionName = region.identifier;
    
    [self addLocalNotificationForRecord:record];
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    TraceRecord *record = [TraceRecord new];
    record.recordAt = [NSDate date];
    record.recordType = TraceRecordTypeExit;
    record.positionName = region.identifier;
    
    [self addLocalNotificationForRecord:record];
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLCircularRegion *)region {
    NSLog(@"start monitor region: %@, %.4f, %.4f, %.0f", region.identifier, region.center.latitude, region.center.longitude, region.radius);
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    NSLog(@"location failed for region: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"location failed: %@", error);
}

#pragma mark - Helper

- (BOOL)isValidPosition:(PositionInfo *)positionInfo {
    __block BOOL exist = NO;

    [self.locationManager.monitoredRegions enumerateObjectsUsingBlock:^(__kindof CLRegion * _Nonnull obj, BOOL * _Nonnull stop) {
        CLCircularRegion *region = (CLCircularRegion *)obj;
        if ([region.identifier isEqualToString:positionInfo.identifier]
            && fabs(region.center.latitude - positionInfo.lat) < 0.001
            && fabs(region.center.longitude - positionInfo.lng) < 0.001) {
            exist = YES;
            *stop = YES;
        }
    }];
    return exist;
}

- (void)addLocalNotificationForRecord:(TraceRecord *)record {
    [self.records addObject:record];
    [self syncRecords];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yy-MM-dd HH:mm"];
    
    NSString *recordTypeStr = record.recordType == TraceRecordTypeEnter ? NSLocalizedString(@"Enter", nil) : NSLocalizedString(@"Exit", nil);
    NSString *message = [NSString stringWithFormat:@"%@ %@ [%@]", recordTypeStr, record.positionName, [dateFormatter stringFromDate:record.recordAt]];
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = message;
    notification.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    NSLog(@"%@", message);
}

- (CLCircularRegion *)regionWithId:(NSString *)identifier {
    for (CLCircularRegion *region in self.locationManager.monitoredRegions) {
        if ([region.identifier isEqualToString:identifier])
            return region;
    }
    return nil;
}

- (void)geoOnebyOne {
    [self.positions enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PositionInfo *positionInfo = (PositionInfo *)obj;
        if (!positionInfo.address) {
            [self asyncGeoForPosition:positionInfo];
            *stop = YES;
        }
    }];
}

- (void)addPositionInfo:(PositionInfo *)positionInfo {
    [self addMonitorForPosition:positionInfo];
    
    [[[RegionManager sharedInstance] positions] addObject:positionInfo];
    [[RegionManager sharedInstance] syncPositions];    
    [[RegionManager sharedInstance] asyncGeoForPosition:positionInfo];
}

- (void)addMonitorForPosition:(PositionInfo *)positionInfo {
    CLCircularRegion *region = [self regionWithId:positionInfo.identifier];
    if (region) [self.locationManager stopMonitoringForRegion:region];
    
    region = [[CLCircularRegion alloc] initWithCenter:CLLocationCoordinate2DMake(positionInfo.lat, positionInfo.lng) radius:100 identifier:positionInfo.identifier];
    [[RegionManager sharedInstance].locationManager startMonitoringForRegion:region];
}

- (void)syncPositions {
    NSString *jsonStr = [self.positions yy_modelToJSONString];
    [[NSUserDefaults standardUserDefaults] setObject:jsonStr forKey:@"StoredPositions"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)syncRecords {
    NSString *jsonStr = [self.records yy_modelToJSONString];
    [[NSUserDefaults standardUserDefaults] setObject:jsonStr forKey:@"StoredRecords"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)asyncGeoForPosition:(PositionInfo *)positionInfo {
    CLLocation *location = [[CLLocation alloc] initWithLatitude:positionInfo.lat longitude:positionInfo.lng];
    [self.geocoder reverseGeocodeLocation:location  completionHandler:^(NSArray *placemarks, NSError *error) {
        if (error == nil && [placemarks count] > 0) {
            CLPlacemark *placemark = [placemarks lastObject];
            positionInfo.address = [NSString stringWithFormat:@"%@ %@", placemark.administrativeArea, placemark.locality];
            if (placemark.subLocality)
                positionInfo.address = [positionInfo.address stringByAppendingFormat:@" %@", placemark.subLocality];
            if (placemark.thoroughfare)
                positionInfo.address = [positionInfo.address stringByAppendingFormat:@" %@", placemark.thoroughfare];
            if (placemark.subThoroughfare)
                positionInfo.address = [positionInfo.address stringByAppendingFormat:@" %@", placemark.subThoroughfare];
            
            if ([self.delegate respondsToSelector:@selector(positionGeoUpdated:)])
                [self.delegate positionGeoUpdated:positionInfo];            
        } else {
            NSLog(@"%@", error.debugDescription);
        }
        [self geoOnebyOne];
    } ];
}

- (void)monitorAllPositions {
    for (PositionInfo *positionInfo in self.positions) {
        [self addMonitorForPosition:positionInfo];
    }
}

@end
