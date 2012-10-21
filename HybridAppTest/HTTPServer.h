//
//  HTTPServer.h
//  HybridAppTest
//
//  Created by Lars Hoss on 21.10.12.
//  Copyright (c) 2012 Lars Hoss. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HTTPServer : NSObject {
    dispatch_queue_t socketQueue;
}

- (id)init;
- (void)start;

@end
