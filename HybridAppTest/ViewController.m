//
//  ViewController.m
//  HybridAppTest
//
//  Created by Lars Hoss on 20.10.12.
//  Copyright (c) 2012 Lars Hoss. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

- (void)wantsToShare:(NSNotification *)notification;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Watch for events
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(wantsToShare:)
                                                 name:@"FBShare"
                                               object:nil];
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:8080"]]];
}

- (void)wantsToShare:(NSNotification *)notification {
    
    SLComposeViewController *ctrl = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
    [ctrl setInitialText:[notification object]];
    [self presentViewController:ctrl animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
