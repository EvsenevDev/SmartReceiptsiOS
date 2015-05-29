//
//  DataImport.m
//  SmartReceipts
//
//  Created by Jaanus Siim on 27/05/15.
//  Copyright (c) 2015 Will Baumann. All rights reserved.
//

#import <objective-zip/ZipReadStream.h>
#import "DataImport.h"
#import "ZipFile.h"
#import "Constants.h"
#import "FileInZipInfo.h"
#import "WBFileManager.h"
#import "WBPreferences.h"

@interface DataImport ()

@property (nonatomic, copy) NSString *inputPath;
@property (nonatomic, copy) NSString *outputPath;

@end

@implementation DataImport

- (id)initWithInputFile:(NSString *)inputPath output:(NSString *)outputPath {
    self = [self init];
    if (self) {
        _inputPath = inputPath;
        _outputPath = outputPath;
    }
    return self;
}

- (void)execute {
    [[NSFileManager defaultManager] createDirectoryAtPath:self.outputPath withIntermediateDirectories:YES attributes:nil error:nil];

    ZipFile *zipFile = [[ZipFile alloc] initWithFileName:self.inputPath mode:ZipFileModeUnzip];
    [self extractFromZip:zipFile zipName:SmartReceiptsDatabaseExportName toFile:[self.outputPath stringByAppendingPathComponent:SmartReceiptsDatabaseExportName]];
    NSData *preferences = [self extractDataFromZip:zipFile withName:SmartReceiptsPreferencesExportName];
    [WBPreferences setFromXmlString:[[NSString alloc] initWithData:preferences encoding:NSUTF8StringEncoding]];

    // trips contents
    [zipFile goToFirstFileInZip];
    do {
        FileInZipInfo *info = [zipFile getCurrentFileInZipInfo];
        NSString *name = info.name;
        if ([name isEqualToString:SmartReceiptsDatabaseExportName]) {
            continue;
        }
        if ([name hasPrefix:@"shared_prefs/"]) {
            continue;
        }

        NSArray *components = [name pathComponents];
        if (components.count != 2) {
            continue;
        }

        NSString *tripName = components[0];
        NSString *fileName = components[1];

        SRLog(@"Extract file for trip:%@", tripName);
        NSString *tripPath = [[self.outputPath stringByAppendingPathComponent:SmartReceiptsTripsDirectoryName] stringByAppendingPathComponent:tripName];
        [[NSFileManager defaultManager] createDirectoryAtPath:tripPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *filePath = [tripPath stringByAppendingPathComponent:fileName];
        ZipReadStream *stream = [zipFile readCurrentFileInZip];
        [self writeDataFromStream:stream toFile:filePath];
    } while ([zipFile goToNextFileInZip]);
}

- (NSData *)extractDataFromZip:(ZipFile *)zipFile withName:(NSString *)fileName {
    NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"extract"];
    [self extractFromZip:zipFile zipName:fileName toFile:tempFile];
    NSData *data = [NSData dataWithContentsOfFile:tempFile];
    [[NSFileManager defaultManager] removeItemAtPath:tempFile error:nil];
    return data;
}

- (void)extractFromZip:(ZipFile *)zipFile zipName:(NSString *)zipName toFile:(NSString *)outPath {
    SRLog(@"Extract file named: %@", zipName);
    BOOL found = [zipFile locateFileInZip:zipName];
    if (!found) {
        SRLog(@"File with name %@ not in zip", zipName);
        return;
    }

    ZipReadStream *stream = [zipFile readCurrentFileInZip];
    [self writeDataFromStream:stream toFile:outPath];
}

- (void)writeDataFromStream:(ZipReadStream *)stream toFile:(NSString *)file {
    @autoreleasepool {
        NSMutableData *buffer = [[NSMutableData alloc] initWithLength:(8 * 1024)];
        NSMutableData *resultData = [[NSMutableData alloc] init];
        NSUInteger len;
        while ((len = [stream readDataWithBuffer:buffer]) > 0) {
            [resultData appendBytes:[buffer mutableBytes] length:len];
        }
        [stream finishedReading];

        SRLog(@"File size %tu", resultData.length);
        [WBFileManager forceWriteData:resultData to:file];
        SRLog(@"Written to %@", file);
    }
}

@end
