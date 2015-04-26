//
//  WBTripCsvCreator.h
//  SmartReceipts
//
//  Created on 04/04/14.
//  Copyright (c) 2014 Will Baumann. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/objc.h>

@class WBTrip;

@interface WBTripCsvCreator : NSObject

- (id)initWithColumns:(NSArray *)columns;
- (BOOL)createCsvFileAtPath:(NSString *)filePath receiptsAndIndexes:(NSArray *)receiptsAndIndexes includeHeaders:(BOOL)includeHeaders;

@end
