//
//  NUTrackerSession.m
//  NextUserKit
//
//  Created by NextUser on 11/10/15.
//  Copyright © 2015 NextUser. All rights reserved.
//

#import "NUTrackerSession.h"
#import "NUTrackingHTTPRequestHelper.h"
#import "NUDDLog.h"
#import "NUHTTPRequestUtils.h"
#import "SSKeychain.h"
#import "NSString+LGUtils.h"

#define kDeviceCookieSerializationKey @"nu_device_ide"

#define kDeviceCookieJSONKey @"device_cookie"
#define kSessionCookieJSONKey @"session_cookie"

#define kKeychainServiceName @"com.nextuser.nextuserkit"


@implementation NUTrackerSession

#pragma mark - Public API

- (id)init
{
    if (self = [super init]) {
        
        // this makes sure that we never migrate keychain data to another device (e.g. iTunes restore from backup)
        [SSKeychain setAccessibilityType:kSecAttrAccessibleAlwaysThisDeviceOnly];
    }
    
    return self;
}

- (void)startWithTrackIdentifier:(NSString *)trackIdentifier completion:(void(^)(NSError *error))completion;
{
    DDLogInfo(@"Start tracker session");
    if (!_startupRequestInProgress) {
        
        _startupRequestInProgress = YES;

        _deviceCookie = nil;
        _sessionCookie = nil;
        _trackIdentifier = trackIdentifier;
        
        NSString *currentDeviceCookie = [self serializedDeviceCookie];
        
        NSDictionary *parameters = nil;
        NSString *path = [self sessionURLPathWithDeviceCookie:currentDeviceCookie URLParameters:&parameters];
        
        DDLogVerbose(@"Fire HTTP request to start the session. Path: %@, Parameters: %@", path, parameters);
        [NUHTTPRequestUtils sendGETRequestWithPath:path
                                        parameters:parameters
                                        completion:^(id responseObject, NSError *error) {
                                            
                                            _startupRequestInProgress = NO;

                                            if (error == nil) {
                                                
                                                DDLogVerbose(@"Start tracker session response: %@", responseObject);
                                                
                                                _deviceCookie = responseObject[kDeviceCookieJSONKey];
                                                _sessionCookie = responseObject[kSessionCookieJSONKey];
                                                
                                                // save new device cookie only if one does not already exists
                                                if (currentDeviceCookie == nil && _deviceCookie != nil) {
                                                    [self serializeDeviceCookie:_deviceCookie];
                                                }
                                                
                                                if (completion != NULL) {
                                                    completion(nil);
                                                }

                                            } else {
                                                
                                                DDLogError(@"Setup tracker error: %@", error);
                                                
                                                if (completion != NULL) {
                                                    completion(error);
                                                }
                                            }
                                        }];
            }
}

- (BOOL)isValid
{
//    return ![NSString lg_isEmptyString:_deviceCookie] &&
//    ![NSString lg_isEmptyString:_sessionCookie] &&
//    ![NSString lg_isEmptyString:_trackIdentifier];
    // refactor to use above category calls. problems with linking category in static library (-all_load "OtherLinkerFlags")
    return _deviceCookie != nil && _deviceCookie.length > 0
    && _sessionCookie != nil && _sessionCookie.length > 0
    && _trackIdentifier != nil && _trackIdentifier.length > 0;
}

#pragma mark - Private API

- (NSString *)sessionURLPathWithDeviceCookie:(NSString *)deviceCookie URLParameters:(NSDictionary **)URLParameters
{
    // e.g. https://track-dev.nextuser.com/sdk.js?tid=internal_tests
    NSString *path = [NUTrackingHTTPRequestHelper pathWithAPIName:@"sdk.js"];
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"tid"] = _trackIdentifier;
    if (deviceCookie) {
        parameters[@"dc"] = deviceCookie;
    }
    
    if (URLParameters != NULL) {
         *URLParameters = parameters;
    }
    
    return path;
}

#pragma mark - Serialization

- (NSString *)keychainSerivceName
{
    NSString *serviceName = kKeychainServiceName;
    
    NSString *appID = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    serviceName = [serviceName stringByAppendingFormat:@"_%@", appID];
    
    return serviceName;
}

- (NSString *)serializedDeviceCookie
{
    NSError *error = nil;
    NSString *password = [SSKeychain passwordForService:[self keychainSerivceName] account:kDeviceCookieSerializationKey error:&error];
    if (error != nil) {
        DDLogError(@"Error while fetching device cookie from keychain. %@", error);
    }
    
    return password;
}

- (void)serializeDeviceCookie:(NSString *)deviceCookie
{
    NSAssert(deviceCookie, @"deviceCookie can not be nil");
    
    NSError *error = nil;
    [SSKeychain setPassword:deviceCookie forService:[self keychainSerivceName] account:kDeviceCookieSerializationKey error:&error];
    if (error != nil) {
        DDLogError(@"Error while setting device cookie in keychain. %@", error);
    }
}

- (void)clearSerializedDeviceCookie
{
    NSError *error = nil;
    [SSKeychain deletePasswordForService:[self keychainSerivceName] account:kDeviceCookieSerializationKey error:&error];
    if (error != nil) {
        DDLogError(@"Error while deleting device cookie from keychain. %@", error);
    }
}

@end
