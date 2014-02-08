//
//  ESTMirrorClient.m
//  EITViewMirror
//
//  Created by Patrik Gebhardt on 06/02/14.
//  Copyright (c) 2014 EST. All rights reserved.
//

#import "ESTMirrorClient.h"
#import "ESTElectrodesRenderer.h"

// request constants
NSString* const ESTMirrorClientRequestElectrodesConfig = @"electrodes";
NSString* const ESTMirrorClientRequestVerticesConfig = @"vertices";
NSString* const ESTMirrorClientRequestColorsConfig = @"colors";
NSString* const ESTMirrorClientRequestVerticesUpdate = @"vertices-update";
NSString* const ESTMirrorClientRequestColorsUpdate = @"colors-update";
NSString* const ESTMirrorClientRequestAnalysisUpdate = @"analysis-update";
NSString* const ESTMirrorClientRequestCalibration = @"calibrate";

@implementation ESTMirrorClient

-(id)initWithHostAddress:(NSURL *)hostAddress {
    if (self = [super init]) {
        // init properties
        self.hostAddress = hostAddress;
    }
    
    return self;
}

-(void)request:(NSString *)request {
    // request at server without expecting response
    NSURLRequest* urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.hostAddress, request]]];
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:[NSOperationQueue mainQueue] completionHandler:nil];
}

-(void)request:(NSString *)request withDataCompletionHandler:(void (^)(NSData *, NSError *))completionHandler {
    // request electrodes configuration from server
    NSURLRequest* urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.hostAddress, request]]];
    
    NSURLSession* urlSession = [NSURLSession sharedSession];
    [[urlSession dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // call completion handler
        completionHandler(data, error);
    }] resume];
}

-(void)request:(NSString *)request withDictionaryCompletionHandler:(void (^)(NSDictionary *, NSError *))completionHandler {
    // request electrodes configuration from server
    NSURLRequest* urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.hostAddress, request]]];
    
    NSURLSession* urlSession = [NSURLSession sharedSession];
    [[urlSession dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // extract data
        NSDictionary* body = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        
        // call completion handler
        completionHandler(body, error);
    }] resume];
}

@end
