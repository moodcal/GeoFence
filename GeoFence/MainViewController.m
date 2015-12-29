//
//  ViewController.m
//  GeoFence
//
//  Created by yanzheng on 15/12/28.
//  Copyright © 2015年 links. All rights reserved.
//

#import "MainViewController.h"
#import "PositionInfo.h"
#import "TraceRecord.h"
#import "PositionCell.h"
#import "RecordController.h"
#import "LocationTransform.h"

@interface MainViewController ()<UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate, CLLocationManagerDelegate, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIButton *addButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *recordsItem;
@property (strong, nonatomic) UIImageView *pinImageView;
- (IBAction)addAction:(id)sender;

@property (strong, nonatomic) NSMutableArray *positions;
@property (strong, nonatomic) NSMutableArray *records;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLGeocoder *geocoder;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"GeoFence", nil);
    [self.addButton setTitle:NSLocalizedString(@"Add", nil) forState:UIControlStateNormal];
    self.recordsItem.title = NSLocalizedString(@"Records", nil);
    self.geocoder = [[CLGeocoder alloc] init];
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    [self.locationManager requestWhenInUseAuthorization];
    [self.locationManager startUpdatingLocation];
    self.pinImageView = [[UIImageView alloc] initWithFrame:CGRectMake(-100, -100, 16, 24)];
    self.pinImageView.image = [UIImage imageNamed:@"pin"];
    [self.mapView addSubview:self.pinImageView];
    self.mapView.showsUserLocation = YES;
    
    NSString *positionJsonStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"StoredPositions"];
    NSString *recordJsonStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"StoredRecords"];
    self.positions = [[NSArray yy_modelArrayWithClass:[PositionInfo class] json:positionJsonStr] mutableCopy];
    self.records = [[NSArray yy_modelArrayWithClass:[TraceRecord class] json:recordJsonStr] mutableCopy];
    if (!self.positions) self.positions = [NSMutableArray array];
    if (!self.records) self.records = [NSMutableArray array];
    
    [self geoOnebyOne];
}

- (void)viewDidAppear:(BOOL)animated {
    self.pinImageView.center = CGPointMake(self.mapView.frame.size.width/2, self.mapView.frame.size.height/2-12);
    
    [super viewDidAppear:animated];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self.view endEditing:YES];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.positions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PositionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PositionCell" forIndexPath:indexPath];
    PositionInfo *positionInfo = [self.positions objectAtIndex:indexPath.row];
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

    cell.nameTextField.textColor = exist ? [UIColor blackColor] : [UIColor redColor];
    cell.nameTextField.text = positionInfo.identifier;
    cell.nameTextField.tag = indexPath.row;
    cell.addressLabel.text = positionInfo.address ? positionInfo.address : [NSString stringWithFormat:@"%.3f, %.3f", positionInfo.lat, positionInfo.lng];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PositionInfo *positionInfo = [self.positions objectAtIndex:indexPath.row];
    CLLocationCoordinate2D center = CLLocationCoordinate2DMake(positionInfo.lat, positionInfo.lng);
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(center, 800, 800);
    [self showLocation:region.center];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        PositionInfo *positionInfo = [self.positions objectAtIndex:indexPath.row];
        CLCircularRegion *region = [self regionWithId:positionInfo.identifier];
        [self.locationManager stopMonitoringForRegion:region];
        [self.positions removeObject:positionInfo];
        [self syncPositions];
    }
}

#pragma mark - Segue
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"PushRecordSegue"]) {
        RecordController *recordController = (RecordController *)segue.destinationViewController;
        recordController.records = self.records.reverseObjectEnumerator.allObjects;
        recordController.title = NSLocalizedString(@"Records", nil);
    }
}

#pragma mark - LocationManager Delegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    for (CLLocation *location in locations) {
        if ([location.timestamp timeIntervalSinceNow] > -30.0) {
            [self showLocation:location.coordinate];
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

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    NSLog(@"location failed for region: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"location failed: %@", error);
}

#pragma mark - TextField Delegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.text.length == 0)
        return NO;
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField.text.length == 0)
        return;
    
    NSUInteger index = textField.tag;
    PositionInfo *positionInfo = [self.positions objectAtIndex:index];
    CLCircularRegion *region = [self regionWithId:positionInfo.identifier];
    [self.locationManager stopMonitoringForRegion:region];
    positionInfo.identifier = textField.text;
    [self syncPositions];
    
    CLCircularRegion *newRegion = [[CLCircularRegion alloc] initWithCenter:region.center radius:300 identifier:positionInfo.identifier];
    [self.locationManager startMonitoringForRegion:newRegion];
    
    [textField resignFirstResponder];
}

#pragma mark - Actions

- (IBAction)addAction:(id)sender {
    PositionInfo *positionInfo = [PositionInfo new];
    positionInfo.identifier = [NSString stringWithFormat:@"position_%ld", (long)self.positions.count];
    CLLocationCoordinate2D gpsCoordinate = [LocationTransform gpsForGmapLoc:self.mapView.centerCoordinate];
    positionInfo.lat = gpsCoordinate.latitude;
    positionInfo.lng = gpsCoordinate.longitude;

    CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:gpsCoordinate radius:300 identifier:positionInfo.identifier];
    [self.locationManager startMonitoringForRegion:region];
    [self.positions addObject:positionInfo];
    [self syncPositions];
    
    [self asyncGeoForPosition:positionInfo];
}

#pragma mark - Helpers

- (void)syncPositions {
    NSString *jsonStr = [self.positions yy_modelToJSONString];
    [[NSUserDefaults standardUserDefaults] setObject:jsonStr forKey:@"StoredPositions"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.tableView reloadData];
}

- (void)showLocation:(CLLocationCoordinate2D)gpsCoordinate {
    CLLocationCoordinate2D mapCoordiante = [LocationTransform gmapLocForGps:gpsCoordinate];
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(mapCoordiante, 800, 800);
    [self.mapView setRegion:region animated:YES];
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
            [self.tableView reloadData];
        } else {
            NSLog(@"%@", error.debugDescription);
        }
        [self geoOnebyOne];
    } ];
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

- (void)addLocalNotificationForRecord:(TraceRecord *)record {
    [self.records addObject:record];
    NSString *jsonStr = [self.records yy_modelToJSONString];
    [[NSUserDefaults standardUserDefaults] setObject:jsonStr forKey:@"StoredRecords"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yy-MM-dd HH:mm"];

    UILocalNotification *notification = [[UILocalNotification alloc] init];
    NSString *recordTypeStr = record.recordType == TraceRecordTypeEnter ? NSLocalizedString(@"Enter", nil) : NSLocalizedString(@"Exit", nil);
    NSString *message = [NSString stringWithFormat:@"%@ %@ [%@]", recordTypeStr, record.positionName, [dateFormatter stringFromDate:record.recordAt]];
    [notification setAlertBody:message];
    [notification setFireDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    [notification setTimeZone:[NSTimeZone  defaultTimeZone]];
    [[UIApplication sharedApplication] setScheduledLocalNotifications:[NSArray arrayWithObject:notification]];
}

- (CLCircularRegion *)regionWithId:(NSString *)identifier {
    for (CLCircularRegion *region in self.locationManager.monitoredRegions) {
        if ([region.identifier isEqualToString:identifier])
            return region;
    }
    return nil;
}


@end
