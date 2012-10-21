//
//  HTTPServer.m
//  HybridAppTest
//
//  Created by Lars Hoss on 21.10.12.
//  Copyright (c) 2012 Lars Hoss. All rights reserved.
//

#import "HTTPServer.h"
#import "GCDAsyncSocket.h"
#import "Backend.h"

#define HTTP_HEADER 0
#define HTTP_BODY 1
#define HTTP_RESPONSE 10

@interface HTTPServer ()

- (void)parseHTTPHeader:(NSString *)content socket:(GCDAsyncSocket *)sock;
- (void)handleGETRequest:(NSString *)request header:(NSDictionary *)dict socket:(GCDAsyncSocket *)sock;
- (void)handlePOSTRequest:(NSString *)request header:(NSDictionary *)dict socket:(GCDAsyncSocket *)sock;
- (void)handlePOSTBody:(NSString *)content socket:(GCDAsyncSocket *)sock;

@property (nonatomic, strong) Backend *backend;
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) NSMutableArray *sockets;

@end

@implementation HTTPServer

- (id)init {
    if ((self = [super init])) {
        self.sockets = [[NSMutableArray alloc] initWithCapacity:1];
        self.backend = [[Backend alloc] init];
    }
    return self;
}


- (void)start {
    // Initialize socket
    NSError *error = nil;
    
    socketQueue = dispatch_queue_create("socketQueue", NULL);
    
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
    NSLog(@"self.socket: %@", self.socket);
    if (![self.socket acceptOnPort:8080 error:&error]) {
        NSLog(@"Couldn't set up socket: %@", error);
        // TODO: Error reporting
    }
}

- (void)parseHTTPHeader:(NSString *)header socket:(GCDAsyncSocket *)sock {

    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSLog(@"%@", header);
        }
    });
    NSArray *lines = [header componentsSeparatedByString:@"\n"];
    
    // Parse the header into a NSDictionary
    NSError *error;
    NSRegularExpression *reg = [NSRegularExpression regularExpressionWithPattern:@"\\A([\\w-]+): (.*)"
                                                                         options:0
                                                                           error:&error];    
    NSMutableDictionary *headerDict = [NSMutableDictionary dictionary];
    for(NSString *line in lines) {
        NSArray *matches = [reg matchesInString:line
                                        options:0
                                          range:NSMakeRange(0, [line length])];
        for(NSTextCheckingResult *res in matches) {
            //NSLog(@"location: %d", res.range.location);
            //NSLog(@"length: %d", res.range.length);
            NSString *key = [line substringWithRange:[res rangeAtIndex:1]];
            NSString *value = [line substringWithRange:[res rangeAtIndex:2]];
            //NSLog(@"key: %@", key);
            //NSLog(@"value: %@", value);
            [headerDict setObject:value forKey:key];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSLog(@"%@", headerDict);
        }
    });
    
    // Detect GET or POST request
    if ([lines[0] hasPrefix:@"GET"]) {
        [self handleGETRequest:lines[0] header:headerDict socket:sock];
    } else {
        [self handlePOSTRequest:lines[0] header:headerDict socket:sock];
    }
}

- (void)handleGETRequest:(NSString *)request header:(NSDictionary *)header socket:(GCDAsyncSocket *)sock {
    NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];

    NSArray *firstLineComps = [request componentsSeparatedByString:@" "];
    NSString *resource = firstLineComps[1];
    
    if ([resource isEqualToString:@"/"]) {
        resource = @"/index.html";
    }
    
    NSString *path = [NSString stringWithFormat:@"html%@", resource];
    NSURL *fileURL = [bundleURL URLByAppendingPathComponent:path];
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSLog(@"Serving static file: %@", fileURL);
        }
    });
    
    NSData *responseData = [NSData dataWithContentsOfURL:fileURL];
    [sock writeData:responseData withTimeout:-1 tag:HTTP_RESPONSE];
    [sock disconnectAfterWriting];
}

- (void)handlePOSTRequest:(NSString *)request header:(NSDictionary *)dict socket:(GCDAsyncSocket *)sock {
    // How many bytes do we have to read for the body?
    NSNumber *bytesToRead = [dict objectForKey:@"Content-Length"];
    [sock readDataToLength:[bytesToRead unsignedIntValue] withTimeout:-1 tag:HTTP_BODY];
}

- (void)handlePOSTBody:(NSString *)body socket:(GCDAsyncSocket *)sock {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSLog(@"body: %@", body);
        }
    });

    NSString *jsonData = [body substringFromIndex:8];
    jsonData = [jsonData stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    jsonData = [jsonData stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error;
    NSDictionary *jsonObj = [NSJSONSerialization JSONObjectWithData:[jsonData dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:NSJSONReadingAllowFragments
                                                              error:&error];

    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSLog(@"jsonData: %@", jsonData);
            NSLog(@"json object: %@", jsonObj);
            NSLog(@"Calling action: %@", jsonObj[@"action"]);
        }
    });
    
    NSDictionary *params = jsonObj[@"params"];
    //SEL selector = NSSelectorFromString([jsonObj[@"action"] stringByAppendingString:@":"]);
    SEL selector = @selector(share:);
    NSMethodSignature *methodSig = [[self.backend class] instanceMethodSignatureForSelector:selector];
    NSLog(@"numArgs: %d", [methodSig numberOfArguments]);
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:methodSig];
    [inv setSelector:selector];
    [inv setTarget:self.backend];
    [inv setArgument:&params atIndex:2];
    [inv invoke];
    
    NSDictionary *result;
    [inv getReturnValue:&result];
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:result
                                                   options:0
                                                     error:&error];
    NSString *jsonOutString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSMutableString *responseString = [NSMutableString stringWithString:@""];
    
    [responseString appendString:@"HTTP/1.0 200 OK\r\n"];
    [responseString appendString:@"Content-Type: text/plain; charset=UTF-8\r\n"];
    [responseString appendString:@"\r\n"];
    [responseString appendString:jsonOutString];
    
    NSData * responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
    [sock writeData:responseData withTimeout:-1 tag:HTTP_RESPONSE];
    [sock disconnectAfterWriting];    
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"didAcceptNewSocket!");
    });

    @synchronized(self.sockets) {
        [self.sockets addObject:newSocket];
	}
    
    NSData *term = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    [newSocket readDataToData:term withTimeout:-1 tag:HTTP_HEADER];    
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {

    // Breakes the code?
    // NSString *content = [NSString stringWithCString:[data bytes] encoding:NSUTF8StringEncoding];
    
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSLog(@"didReadData -> bytes read: %d", [data length]);
            NSLog(@"didReadData -> content: %@", content);
        }
    });
    
    if (tag == HTTP_HEADER) {
        [self parseHTTPHeader:content socket:sock];
    } else if (tag == HTTP_BODY) {
        [self handlePOSTBody:content socket:sock];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock {
    NSLog(@"onSocketDidDisconnect");
    [self.sockets removeObject:sock];
}

@end
