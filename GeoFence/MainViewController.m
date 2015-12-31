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

#define MapScaleDistance 2000

@interface MainViewController ()<UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate, UITextFieldDelegate, RegionManagerDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIButton *addButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *recordsItem;
@property (strong, nonatomic) UIImageView *pinImageView;
@property (strong, nonatomic) RegionManager *regionManager;
- (IBAction)addMonitorAction:(id)sender;
- (IBAction)cellLongPressAction:(id)sender;
- (IBAction)showCurrentLocation:(id)sender;
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
    cell.addressLabel.text = [cell.addressLabel.text stringByAppendingFormat:@" [%ldm]", positionInfo.radius];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PositionInfo *positionInfo = [[self.regionManager positions] objectAtIndex:indexPath.row];
    [self showPositionInMap:positionInfo];
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

#pragma mark - MapView delegate

- (MKOverlayRenderer *) mapView:(MKMapView *)mapView rendererForOverlay:(id)overlay {
    if([overlay isKindOfClass:[MKCircle class]]) {
        MKCircleRenderer* aRenderer = [[MKCircleRenderer alloc] initWithCircle:(MKCircle *)overlay];
        aRenderer.fillColor = [[UIColor blueColor] colorWithAlphaComponent:0.4];
        aRenderer.strokeColor = [[UIColor grayColor] colorWithAlphaComponent:0.9];
        aRenderer.lineWidth = 2;
        aRenderer.lineDashPattern = @[@2, @5];
        aRenderer.alpha = 0.5;
        return aRenderer;
    } else {
        return nil;
    }
}

#pragma mark - RegionManager Delegate
- (void)positionGeoUpdated:(PositionInfo *)positionInfo {
    [self.tableView reloadData];
}

- (void)locationDidUpdated:(CLLocationCoordinate2D)coordinate {
    [self showCurrentLocation:nil];
}

#pragma mark - Segue
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"PushRecordSegue"]) {
        RecordController *recordController = (RecordController *)segue.destinationViewController;
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
    positionInfo.radius = 100;
    
    [self.regionManager addPositionInfo:positionInfo];
    [self.tableView reloadData];
}

- (IBAction)cellLongPressAction:(UILongPressGestureRecognizer *)sender {
    CGPoint touchPoint = [sender locationInView:self.view];
    NSIndexPath* indexPath = [self.tableView indexPathForRowAtPoint:touchPoint];
    PositionInfo *positionInfo = [self.regionManager.positions objectAtIndex:indexPath.row];
    
    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"Monitor radius" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [NSString stringWithFormat:@"%ld", positionInfo.radius];
    }];

    UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        UITextField *textField = alertController.textFields.firstObject;
        positionInfo.radius = textField.text.integerValue;
        [self.regionManager addMonitorForPosition:positionInfo];
        [[RegionManager sharedInstance] syncPositions];
        [self showPositionInMap:positionInfo];
        [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        [self.tableView reloadData];
    }];
    
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)showPositionInMap:(PositionInfo *)positionInfo {
    CLLocationCoordinate2D center = CLLocationCoordinate2DMake(positionInfo.lat, positionInfo.lng);
    CLLocationCoordinate2D mapcoordinate = [LocationTransform gmapLocForGps:center];
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(mapcoordinate, MapScaleDistance, MapScaleDistance);
    [self showRegion:region radius:positionInfo.radius];
}

- (IBAction)showCurrentLocation:(id)sender {
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(self.mapView.userLocation.location.coordinate, MapScaleDistance, MapScaleDistance);
    [self.mapView setRegion:region animated:YES];
}

- (void)alertTextFieldDidChanged:(id)sender {
}

#pragma mark - Helpers

- (void)showRegion:(MKCoordinateRegion)region radius:(CLLocationDistance)radius {
    [self.mapView setRegion:region animated:YES];
    [self.mapView removeOverlays:self.mapView.overlays];
    MKCircle *circle = [MKCircle circleWithCenterCoordinate:region.center radius:radius];
    [self.mapView addOverlay:circle];
}

@end
