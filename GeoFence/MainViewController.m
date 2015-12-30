//
//  ViewController.m
//  GeoFence
//
//  Created by yanzheng on 15/12/28.
//  Copyright © 2015年 links. All rights reserved.
//

#import "MainViewController.h"
#import "PositionCell.h"
#import "RecordController.h"
#import "LocationTransform.h"
#import "RegionManager.h"

@interface MainViewController ()<UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate, UITextFieldDelegate, RegionManagerDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIButton *addButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *recordsItem;
@property (strong, nonatomic) UIImageView *pinImageView;
@property (strong, nonatomic) RegionManager *regionManager;
- (IBAction)addMonitorAction:(id)sender;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"GeoFence", nil);
    [self.addButton setTitle:NSLocalizedString(@"Add", nil) forState:UIControlStateNormal];
    self.recordsItem.title = NSLocalizedString(@"Records", nil);
    self.pinImageView = [[UIImageView alloc] initWithFrame:CGRectMake(-100, -100, 16, 24)];
    self.pinImageView.image = [UIImage imageNamed:@"pin"];
    [self.mapView addSubview:self.pinImageView];
    self.mapView.showsUserLocation = YES;
    self.regionManager = [RegionManager sharedInstance];
    [self.regionManager geoOnebyOne];
    self.regionManager.delegate = self;
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
    return [[self.regionManager positions] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PositionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PositionCell" forIndexPath:indexPath];
    PositionInfo *positionInfo = [[self.regionManager positions] objectAtIndex:indexPath.row];

    cell.nameTextField.textColor = [self.regionManager isValidPosition:positionInfo] ? [UIColor blackColor] : [UIColor redColor];
    cell.nameTextField.text = positionInfo.identifier;
    cell.nameTextField.tag = indexPath.row;
    cell.addressLabel.text = positionInfo.address ? positionInfo.address : [NSString stringWithFormat:@"%.3f, %.3f", positionInfo.lat, positionInfo.lng];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PositionInfo *positionInfo = [[self.regionManager positions] objectAtIndex:indexPath.row];
    CLLocationCoordinate2D center = CLLocationCoordinate2DMake(positionInfo.lat, positionInfo.lng);
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(center, 800, 800);
    [self showMapWithGPS:region.center];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        PositionInfo *positionInfo = [[self.regionManager positions] objectAtIndex:indexPath.row];
        CLCircularRegion *region = [self.regionManager regionWithId:positionInfo.identifier];
        [self.regionManager.locationManager stopMonitoringForRegion:region];
        [[self.regionManager positions] removeObject:positionInfo];
        [self.tableView reloadData];
        [self.regionManager syncPositions];
    }
}

#pragma mark - RegionManager Delegate
- (void)positionGeoUpdated:(PositionInfo *)positionInfo {
    [self.tableView reloadData];
}

- (void)locationDidUpdated:(CLLocationCoordinate2D)coordinate {
    [self showMapWithGPS:coordinate];
}

#pragma mark - Segue
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"PushRecordSegue"]) {
        RecordController *recordController = (RecordController *)segue.destinationViewController;
        recordController.records = self.regionManager.records.reverseObjectEnumerator.allObjects;
        recordController.title = NSLocalizedString(@"Records", nil);
    }
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
    PositionInfo *positionInfo = [[self.regionManager positions] objectAtIndex:index];
    CLCircularRegion *region = [self.regionManager regionWithId:positionInfo.identifier];
    [self.regionManager.locationManager stopMonitoringForRegion:region];
    positionInfo.identifier = textField.text;

    [self.regionManager addMonitorForPosition:positionInfo];
    [[RegionManager sharedInstance] syncPositions];

    [textField resignFirstResponder];
}

#pragma mark - Actions

- (IBAction)addMonitorAction:(id)sender {
    PositionInfo *positionInfo = [PositionInfo new];
    positionInfo.identifier = [NSString stringWithFormat:@"position_%ld", (long)[self.regionManager positions].count];
    CLLocationCoordinate2D gpsCoordinate = [LocationTransform gpsForGmapLoc:self.mapView.centerCoordinate];
    positionInfo.lat = gpsCoordinate.latitude;
    positionInfo.lng = gpsCoordinate.longitude;
    
    [self.regionManager addPositionInfo:positionInfo];
    [self.tableView reloadData];
}

#pragma mark - Helpers

- (void)showMapWithGPS:(CLLocationCoordinate2D)gpsCoordinate {
    CLLocationCoordinate2D mapcoordinate = [LocationTransform gmapLocForGps:gpsCoordinate];
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(mapcoordinate, 800, 800);
    [self.mapView setRegion:region animated:YES];
}

@end
