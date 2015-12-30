//
//  RecordController.m
//  GeoFence
//
//  Created by yanzheng on 15/12/29.
//  Copyright © 2015年 links. All rights reserved.
//

#import "RecordController.h"
#import "TraceRecord.h"
#import "RecordCell.h"
#import "RegionManager.h"

@interface RecordController ()
- (IBAction)removeAllRecords:(id)sender;

@end

@implementation RecordController

- (void)viewDidLoad {
    [super viewDidLoad];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[RegionManager sharedInstance] records] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RecordCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RecordCell" forIndexPath:indexPath];
    TraceRecord *record = [[[RegionManager sharedInstance] records] objectAtIndex:indexPath.row];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yy-MM-dd HH:mm"];
    
    cell.typeLabel.text = record.recordType == TraceRecordTypeEnter ? @"到达" : @"离开";
    cell.positionLabel.text = record.positionName;
    cell.timeLabel.text = [dateFormatter stringFromDate:record.recordAt];
    
    return cell;
}

- (IBAction)removeAllRecords:(id)sender {
    [[[RegionManager sharedInstance] records] removeAllObjects];
    [[RegionManager sharedInstance] syncRecords];
    [self.tableView reloadData];
}

@end
