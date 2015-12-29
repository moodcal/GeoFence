//
//  ViewController.m
//  GeoFence
//
//  Created by yanzheng on 15/12/28.
//  Copyright © 2015年 links. All rights reserved.
//

#import "MainViewController.h"
#import "PositionInfo.h"

@interface MainViewController ()<UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate, CLLocationManagerDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) NSMutableArray *positions;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *currentLocation;
@property (weak, nonatomic) IBOutlet UIButton *addButton;
@property (strong, nonatomic) UIImageView *pinImageView;
- (IBAction)addAction:(id)sender;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"位置监控";
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    [self.locationManager requestWhenInUseAuthorization];
    [self.locationManager startUpdatingLocation];
    self.pinImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 10, 20)];
    self.pinImageView.backgroundColor = [UIColor redColor];
    [self.mapView addSubview:self.pinImageView];
    NSString *jsonStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"StoredPositions"];
    self.positions = [[NSArray yy_modelArrayWithClass:[PositionInfo class] json:jsonStr] mutableCopy];
    if (!self.positions)
        self.positions = [NSMutableArray array];
}

- (void)viewDidAppear:(BOOL)animated {
    self.pinImageView.center = CGPointMake(self.mapView.frame.size.width/2, self.mapView.frame.size.height/2);
    [super viewDidAppear:animated];
}

#pragma mark - TableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.positions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PositionCell" forIndexPath:indexPath];
    PositionInfo *positionInfo = [self.positions objectAtIndex:indexPath.row];
    UILabel *nameLabel = (UILabel *)[cell viewWithTag:1];
    UILabel *addressLabel = (UILabel *)[cell viewWithTag:3];
    nameLabel.text = positionInfo.identifier;
    addressLabel.text = [NSString stringWithFormat:@"%.3f, %.3f", positionInfo.lat, positionInfo.lng];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PositionInfo *positionInfo = [self.positions objectAtIndex:indexPath.row];
    CLLocationCoordinate2D center = CLLocationCoordinate2DMake(positionInfo.lat, positionInfo.lng);
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(center, 800, 800);
    [self.mapView setRegion:region animated:YES];
}

- (void)updateCurrentLocation:(CLLocation *)location {
    self.currentLocation = location;
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(self.currentLocation.coordinate, 800, 800);
    [self.mapView setRegion:region animated:YES];
}

#pragma mark - LocationManager Delegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    for (CLLocation *location in locations) {
        if ([location.timestamp timeIntervalSinceNow] > -30.0) {
            [self updateCurrentLocation:location];
            return;
        }
    }
}

-(void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    NSLog(@"Enter region: %@", region.identifier);
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    NSLog(@"Exit region: %@", region.identifier);
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    NSLog(@"location failed for region: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"location failed: %@", error);
}

#pragma mark - Actions

- (IBAction)addAction:(id)sender {
    CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:self.mapView.centerCoordinate radius:300 identifier:@"Home"];
    [self.locationManager startMonitoringForRegion:region];
    PositionInfo *positionInfo = [PositionInfo new];
    positionInfo.identifier = [NSString stringWithFormat:@"position_%ld", (long)self.positions.count];
    positionInfo.lat = self.mapView.centerCoordinate.latitude;
    positionInfo.lng = self.mapView.centerCoordinate.longitude;
    [self.positions addObject:positionInfo];
    [self syncPositions];
}

- (void)syncPositions {
    NSString *jsonStr = [self.positions yy_modelToJSONString];
    [[NSUserDefaults standardUserDefaults] setObject:jsonStr forKey:@"StoredPositions"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.tableView reloadData];
}

@end
