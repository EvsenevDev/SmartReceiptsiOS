//
//  DatabaseQueryBuilderTest.m
//  SmartReceipts
//
//  Created by Jaanus Siim on 02/05/15.
//  Copyright (c) 2015 Will Baumann. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "DatabaseQueryBuilder.h"

@interface DatabaseQueryBuilderTest : XCTestCase

@end

@implementation DatabaseQueryBuilderTest

- (void)testInsertQueryBuild {
    DatabaseQueryBuilder *statement = [DatabaseQueryBuilder insertStatementForTable:@"testing_query"];
    [statement addParam:@"one" value:@1];
    [statement addParam:@"three" value:@"long"];
    [statement addParam:@"two" value:@"pretty"];

    NSString *query = [statement buildStatement];
    NSString *expected = @"INSERT INTO testing_query (one, three, two) VALUES (:one, :three, :two)";
    XCTAssertEqualObjects(expected, query, @"Got %@", query);

    NSDictionary *params = [statement parameters];
    XCTAssertEqual(@1, params[@"one"]);
    XCTAssertEqual(@"long", params[@"three"]);
    XCTAssertEqual(@"pretty", params[@"two"]);
}

- (void)testDeleteQueryBuild {
    DatabaseQueryBuilder *statement = [DatabaseQueryBuilder deleteStatementForTable:@"testing_delete"];
    [statement addParam:@"id" value:@12];

    NSString *query = [statement buildStatement];
    NSString *expected = @"DELETE FROM testing_delete WHERE id = :id";
    XCTAssertEqualObjects(expected, query, @"Got %@", query);

    NSDictionary *params = [statement parameters];
    XCTAssertEqual(@12, params[@"id"]);
}

- (void)testUpdateQueryBuild {
    DatabaseQueryBuilder *statement = [DatabaseQueryBuilder updateStatementForTable:@"testing_update"];
    [statement addParam:@"one" value:@1];
    [statement addParam:@"three" value:@"long"];
    [statement addParam:@"two" value:@"pretty"];
    [statement where:@"id" value:@12];

    NSString *query = [statement buildStatement];
    NSString *expected = @"UPDATE testing_update SET one = :one, three = :three, two = :two WHERE id = :id";
    XCTAssertEqualObjects(expected, query, @"Got %@", query);

    NSDictionary *params = [statement parameters];
    XCTAssertEqual(@12, params[@"id"]);
}

@end