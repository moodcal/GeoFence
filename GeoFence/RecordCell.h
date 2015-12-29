//
//  RecordCell.h
//  GeoFence
//
//  Created by yanzheng on 15/12/29.
//  Copyright © 2015年 links. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RecordCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *typeLabel;
@property (weak, nonatomic) IBOutlet UILabel *positionLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;

@end
