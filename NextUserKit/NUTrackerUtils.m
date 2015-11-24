//
//  NUTrackerUtils.m
//  NextUserKit
//
//  Created by Dino on 11/23/15.
//  Copyright © 2015 NextUser. All rights reserved.
//

#import "NUTrackerUtils.h"
#import "NUTrackerSession.h"
#import "NUTrackingHTTPRequestHelper.h"
#import "NUTrackerUtils+Tests.h"
#import "NUDDLog.h"
#import "AFNetworking.h"

@implementation NUTrackerUtils

#pragma mark - Public API

#pragma mark - Track Screen

+ (void)trackScreenWithName:(NSString *)screenName inSession:(NUTrackerSession *)session completion:(void(^)(NSError *error))completion
{
    NSDictionary *parameters = @{@"pv0" : screenName};
    
    [self sendTrackRequestWithParameters:parameters inSession:session completion:completion];
}

#pragma mark - Track Action

+ (void)trackActionWithName:(NSString *)actionName parameters:(NSArray *)actionParameters inSession:(NUTrackerSession *)session completion:(void(^)(NSError *error))completion
{
    NSArray *actions = @[[NUTrackingHTTPRequestHelper trackActionURLEntryWithName:actionName
                                                                       parameters:actionParameters]];
    [self trackActions:actions
             inSession:session
            completion:completion];
}

+ (NSString *)trackActionURLEntryWithName:(NSString *)actionName parameters:(NSArray *)actionParameters
{
    return [NUTrackingHTTPRequestHelper trackActionURLEntryWithName:actionName parameters:actionParameters];
}

+ (void)trackActions:(NSArray *)actions inSession:(NUTrackerSession *)session completion:(void(^)(NSError *error))completion
{
    // max 10 actions are allowed
    if (actions.count > 10) {
        actions = [actions subarrayWithRange:NSMakeRange(0, 10)];
    }
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:actions.count];
    for (int i=0; i<actions.count; i++) {
        NSString *actionKey = [NSString stringWithFormat:@"a%d", i];
        NSString *actionValue = actions[i];
        
        parameters[actionKey] = actionValue;
    }
    
    [self sendTrackRequestWithParameters:parameters inSession:session completion:completion];
}

#pragma mark - Track Purchase

+ (void)trackPurchaseWithTotalAmount:(double)totalAmount
                            products:(NSArray *)products
                     purchaseDetails:(NUPurchaseDetails *)purchaseDetails
                           inSession:(NUTrackerSession *)session
                          completion:(void(^)(NSError *error))completion
{
    NSDictionary *parameters = @{@"pu0" : [NUTrackingHTTPRequestHelper trackPurchaseParametersStringWithTotalAmount:totalAmount
                                                                                                           products:products
                                                                                                    purchaseDetails:purchaseDetails]};

    [self sendTrackRequestWithParameters:parameters inSession:session completion:completion];
}

#pragma mark - Private API

#pragma mark - HTTP Request

+ (void)sendHTTPGETRequestWithPath:(NSString *)path
                        parameters:(NSDictionary *)parameters
                        completion:(void(^)(NSError *error))completion
{
    DDLogInfo(@"Fire HTTP GET request. Path: %@, Parameters: %@", path, parameters);
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    [manager GET:path
      parameters:parameters
         success:^(AFHTTPRequestOperation *operation, id responseObject) {
             
             DDLogInfo(@"HTTP GET request response");
             DDLogInfo(@"URL: %@", operation.request.URL);
             DDLogInfo(@"Response: %@", responseObject);
             
             if (completion != NULL) {
                 completion(nil);
             }
             
         } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
             
             DDLogError(@"HTTP GET request error");
             DDLogError(@"%@", operation.request.URL);
             DDLogError(@"%@", error);
             
             if (completion != NULL) {
                 completion(error);
             }
         }];
}

#pragma mark - Track Generic

+ (void)sendTrackRequestWithParameters:(NSDictionary *)trackParameters
                             inSession:(NUTrackerSession *)session
                            completion:(void(^)(NSError *error))completion
{
    NSString *path = [self trackingBasePath];
    NSMutableDictionary *parameters = [self defaultTrackingParametersForSession:session includeUserIdentifier:!session.userIdentifierRegistered];
    
    // add track parameters
    for (id key in trackParameters.allKeys) {
        parameters[key] = trackParameters[key];
    }
    
    [self sendHTTPGETRequestWithPath:path parameters:parameters completion:^(NSError *error) {
        
        // we want to make sure that request was successful and that we registered user identifier.
        // only if request was successful we will not send user identifier anymore
        if (error == nil) {
            if ([self hasSessionValidUserIdentifier:session]) {
                session.userIdentifierRegistered = YES;
            }
        }
        
        if (completion != NULL) {
            completion(error);
        }
    }];
}

#pragma mark -

+ (NSString *)trackingBasePath
{
    return [NUTrackingHTTPRequestHelper pathWithAPIName:@"__nutm.gif"];
}

#pragma mark -

+ (NSMutableDictionary *)defaultTrackingParametersForSession:(NUTrackerSession *)session includeUserIdentifier:(BOOL)includeUserIdentifier
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if ([self isSessionValid:session]) {
        parameters[@"nutm_s"] = [self deviceCookieParameterForSession:session];
        parameters[@"nutm_sc"] = session.sessionCookie;
        parameters[@"tid"] = [self trackIdentifierParameterForSession:session appendUserIdentifier:includeUserIdentifier];
    }
    
    return parameters;
}

+ (BOOL)isSessionValid:(NUTrackerSession *)session
{
    return session.deviceCookie != nil && session.sessionCookie != nil && session.trackIdentifier != nil;
}

+ (NSString *)deviceCookieParameterForSession:(NUTrackerSession *)session
{
    return [NSString stringWithFormat:@"...%@", session.deviceCookie];
}

+ (NSString *)trackIdentifierParameterForSession:(NUTrackerSession *)session appendUserIdentifier:(BOOL)appendUserIdentifier
{
    NSString *trackIdentifier = session.trackIdentifier;
    if (appendUserIdentifier && [self hasSessionValidUserIdentifier:session]) {
        trackIdentifier = [trackIdentifier stringByAppendingFormat:@"+%@", session.userIdentifier];
    }
    
    return trackIdentifier;
}

+ (BOOL)hasSessionValidUserIdentifier:(NUTrackerSession *)session
{
    NSString *userIdentifier = session.userIdentifier;
    
    return (userIdentifier != nil && userIdentifier.length > 0);
}

@end
