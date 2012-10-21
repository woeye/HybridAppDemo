//
//  Backend.m
//  HybridAppTest
//
//  Created by Lars Hoss on 21.10.12.
//  Copyright (c) 2012 Lars Hoss. All rights reserved.
//

#import "Backend.h"

@implementation Backend

- (NSDictionary *)share:(NSDictionary *)params {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSLog(@"[Backend] share called: %@", params);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FBShare"
                                                                object:[params objectForKey:@"text"]];
        }
    });
    
    NSDictionary *result = @{
        @"result": @"ok"
    };
    
    return result;
}

@end
