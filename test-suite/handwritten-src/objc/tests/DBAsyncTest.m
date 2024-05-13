#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <DJFuture.h>
#import "DBTestHelpers.h"
#import "DBAsyncInterface.h"

@interface AsyncInterfaceImpl: NSObject<DBAsyncInterface>
@end

@implementation AsyncInterfaceImpl
- (DJFuture<NSString *> *)futureRoundtrip:(DJFuture<NSNumber *> *)f {
    return [f then:^id(DJFuture<NSNumber *> *i) { return [[i get] stringValue]; }];
}
@end

@interface DBAsyncTests : XCTestCase
@end

@implementation DBAsyncTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testConsumeNativeFuture {
    DJFuture<NSNumber *> *f1 = [DBTestHelpers getAsyncResult];
    DJFuture<NSString *> *f2 =[f1 then:^id(DJFuture<NSNumber *> *res) {
            return [[res get] stringValue];
        }];
    DJFuture<NSNumber *> *f3 = [f2 then:^id(DJFuture<NSString *> *res) {
            return @([[res get] integerValue]);
        }];
    NSNumber *i = [f3 get];
    XCTAssertEqual([i integerValue], 42);
}

- (void)testFutureRoundtrip {
    DJPromise<NSString *> *p = [[DJPromise alloc] init];
    DJFuture<NSString *> *f = [p getFuture];
    DJFuture<NSNumber *> *f2 = [f then:^id(DJFuture<NSString *> *s) {
            return @([[s get] integerValue]);
        }];
    DJFuture<NSString *> *f3 = [DBTestHelpers futureRoundtrip:f2];
    [p setValue:@"36"];
    XCTAssertEqualObjects([f3 get], @"36");
}

- (void)testFutureObjCNullable {
    DJPromise<NSNumber *> *p1 = [[DJPromise alloc] init];
    DJFuture<NSNumber *> *f1 = [p1 getFuture];
    [p1 setValue:nil];

    DJPromise<NSNumber *> *p2 = [[DJPromise alloc] init];
    DJFuture<NSNumber *> *f2 = [p2 getFuture];
    [p2 setValue];

    // setValue:nil doesn't set the same value as setValue without parameters.
    // Is this expected? Is it good practice to use [NSNull null], like setValue does?
    // It seems problematic to me, but I lack the ObjC knowledge.
    XCTAssertEqual([f1 get], [f2 get]);
}

- (void)testFutureRoundtripWithNil {
    // This shows a crash that occurs when passing nil into a promise that, on cpp side, doesn't expect nil values
    DJPromise<NSNumber *> *p = [[DJPromise alloc] init];
    DJFuture<NSNumber *> *f = [p getFuture];
    DJFuture<NSString *> *f2 = [DBTestHelpers futureRoundtrip:f];
    [p setValue:nil];
}

- (void)testFutureRoundtripWithNSNull {
    // This shows a crash that occurs when passing [NSNull null] into a promise that, on cpp side, doesn't expect nil values
    DJPromise<NSNumber *> *p = [[DJPromise alloc] init];
    DJFuture<NSNumber *> *f = [p getFuture];
    DJFuture<NSString *> *f2 = [DBTestHelpers futureRoundtrip:f];
    [p setValue];
}

- (void)testFutureRoundtripWithException {
    DJPromise<NSString *> *p = [[DJPromise alloc] init];
    DJFuture<NSString *> *f = [p getFuture];
    DJFuture<NSNumber *> *f2 = [f then:^id(DJFuture<NSString *> *s) {
            if (1) {
                [NSException raise:@"djinni_error" format:@"123"];
            }
            return @([[s get] integerValue]);
        }];
    DJFuture<NSString *> *f3 = [DBTestHelpers futureRoundtrip:f2];
    [p setValue:@"36"];
    NSString *s = nil;
    @try {
        [f3 get];
    } @catch (NSException *e) {
        s = e.reason;
    }
    XCTAssertEqualObjects(s, @"123");
}

- (void) testFutureRoundtripBackwards {
    DJFuture<NSString *> *s = [DBTestHelpers checkAsyncInterface: [[AsyncInterfaceImpl alloc] init]];
    XCTAssertEqualObjects([s get], @"36");
}

- (void) testFutureComposition {
    DJFuture<NSString *> *s = [DBTestHelpers checkAsyncComposition: [[AsyncInterfaceImpl alloc] init]];
    XCTAssertEqualObjects([s get], @"42");
}

- (void) testVoidRoundTrip {
    DJPromise<NSNull *> *p = [[DJPromise alloc] init];
    [p setValue];
    DJFuture<NSNull *>* f = [p getFuture];
    DJFuture<NSNull *>* f1 = [DBTestHelpers voidAsyncMethod:f];
    [f1 get];
}

- (void) testOptionalFuture_unset {
    DJPromise<NSNumber *> *p = [[DJPromise alloc] init];
    [p setValue:nil];
    DJFuture<NSNumber *>* f = [p getFuture];
    DJFuture<NSNumber *>* f1 = [DBTestHelpers addOneIfPresent:f];
    NSNumber * result = [f1 get];
    XCTAssertNil(result);
}

- (void) testOptionalFuture_isSet {
    DJPromise<NSNumber *> *p = [[DJPromise alloc] init];
    [p setValue:@(10)];
    DJFuture<NSNumber *>* f = [p getFuture];
    DJFuture<NSNumber *>* f1 = [DBTestHelpers addOneIfPresent:f];
    NSNumber * result = [f1 get];
    XCTAssertEqual([result intValue], 11);
}

@end
