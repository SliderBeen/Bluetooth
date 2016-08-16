//
//  BraceletTool.h
//  手环
//
//  Created by wist on 16/7/26.
//  Copyright © 2016年 rg. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface BraceletTool : NSObject

+ (instancetype)sharedTool;

- (void)connect;

- (void)disconnect;

@end
