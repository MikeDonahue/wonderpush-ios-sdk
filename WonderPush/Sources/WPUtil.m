/*
 Copyright 2014 WonderPush

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "WPUtil.h"
#import "WPNSUtil.h"
#import "WPConfiguration.h"
#import "WPLog.h"
#import "WonderPush_private.h"
#import "WPMobileProvision.h"
#import <sys/utsname.h>
#import <UIKit/UIApplication.h>
#import <UserNotifications/UserNotifications.h>


NSString * const WPErrorDomain = @"WPErrorDomain";
NSInteger const WPErrorInvalidCredentials = 11000;
NSInteger const WPErrorInvalidAccessToken = 11003;
NSInteger const WPErrorMissingUserConsent = 11011;
NSInteger const WPErrorHTTPFailure = 11012;
NSInteger const WPErrorInvalidFormat = 11013;
NSInteger const WPErrorNotFound = 11014;
@implementation WPUtil

#pragma mark - Device

+ (NSString *)deviceModel
{
    struct utsname systemInfo;
    uname(&systemInfo);

    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}

+ (NSString *)deviceIdentifier
{
    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    NSString *deviceId = conf.deviceId;
    if (deviceId == nil) {
        // Read from local OpenUDID storage to keep a smooth transition off using OpenUDID
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        id localDict = [defaults objectForKey:@"OpenUDID"];
        if ([localDict isKindOfClass:[NSDictionary class]]) {
            id optedOutDate = [localDict objectForKey:@"OpenUDID_optOutTS"];
            if (optedOutDate == nil) {
                deviceId = [localDict objectForKey:@"OpenUDID"];
            }
        }
        if (deviceId == nil) {
            // Generate an UUIDv4
            deviceId = [[NSUUID UUID] UUIDString];
        }
        // Store device id
        conf.deviceId = deviceId;
    }
    return deviceId;
}


#pragma mark - URL Checking

+ (NSDictionary *) paramsForWonderPushURL:(NSURL *)URL
{
    if (!URL.query)
        return @{};

    return [WPNSUtil dictionaryWithFormEncodedString:URL.query];

}


#pragma mark - ERROR

+ (NSError *)errorFromJSON:(id)json
{
    if ([json isKindOfClass:[NSDictionary class]]) {
        NSArray *errorArray = [WPNSUtil arrayForKey:@"error" inDictionary:json];
        NSDictionary *errorDict = [WPNSUtil dictionaryForKey:@"error" inDictionary:json];
        if (errorDict) {
            errorArray = @[errorDict];
        }
        if (errorArray) {
            for (NSDictionary *detailedError in errorArray) {
                if (![detailedError isKindOfClass:[NSDictionary class]]) continue;
                return [[NSError alloc] initWithDomain:WPErrorDomain
                                                  code:[[WPNSUtil numberForKey:@"code" inDictionary:detailedError] integerValue]
                                              userInfo:@{NSLocalizedDescriptionKey : [WPNSUtil stringForKey:@"message" inDictionary:detailedError] ?: [NSNull null]}];
            }
        }
    }
    return nil;
}


#pragma mark - Application utils

+ (BOOL) currentApplicationIsInForeground
{
    return [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
}

static NSArray *backgroundModes = nil;
+ (NSArray *) getBackgroundModes
{
    if (!backgroundModes) {
        NSBundle *bundle = [NSBundle mainBundle];
        backgroundModes = [bundle objectForInfoDictionaryKey:@"UIBackgroundModes"];
    }
    return backgroundModes;
}

static NSNumber *hasBackgroundMode = nil;
+ (BOOL) hasBackgroundModeRemoteNotification
{
    if (hasBackgroundMode == nil) {
        hasBackgroundMode = [NSNumber numberWithBool:NO];
        NSArray *backgroundModes = [WPUtil getBackgroundModes];
        if (backgroundModes != nil) {
            for (NSString *value in backgroundModes) {
                if ([value isEqual:@"remote-notification"]) {
                    WPLogDebug(@"Has background mode remote-notification");
                    hasBackgroundMode = [NSNumber numberWithBool:YES];
                    break;
                }
            }
        }
    }
    return [hasBackgroundMode boolValue];
}

static NSDictionary *entitlements = nil;
+ (NSString *) getEntitlement:(NSString *)key
{
    if (!entitlements) {
        NSDictionary *dict = [WPMobileProvision getMobileProvision];
        entitlements = dict[@"Entitlements"];
    }
    return entitlements[key];
}

static NSNumber *hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler = nil;
+ (BOOL) hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler
{
    if (hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler == nil) {
        hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler =
        [NSNumber numberWithBool:[[UIApplication sharedApplication].delegate
                                  respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]];
        WPLogDebug(@"Has implemented [application:didReceiveRemoteNotification:fetchCompletionHandler:] = %@", hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler);
    }
    return [hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler boolValue];
}

#pragma mark - SERVER TIME

+ (long long) getServerDate
{
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];

    if (configuration.timeOffset == 0) {
        // Not synced, use device time
        return (long long) ([[NSDate date] timeIntervalSince1970] * 1000);
    }
    return (long long) (([[NSProcessInfo processInfo] systemUptime] + configuration.timeOffset) * 1000);
}


# pragma mark - LOCALIZATION

+ (NSString *) localizedStringIfPossible:(NSString *)string
{
    return NSLocalizedStringWithDefaultValue(string, nil, [NSBundle mainBundle], string, nil);
}

+ (NSString *) wpLocalizedString:(NSString *)key withDefault:(NSString *)defaultValue
{
    return [[WonderPush resourceBundle] localizedStringForKey:key value:defaultValue table:@"WonderPushLocalizable"];
}

+ (void) askUserPermission
{
    if (@available(iOS 10.0, *)) {
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (error != nil) {
                WPLog(@"[UNUserNotificationCenter requestAuthorizationWithOptions:completionHandler:] returned an error: %@", error.localizedDescription);
            }
            WPLogDebug(@"[UNUserNotificationCenter requestAuthorizationWithOptions:completionHandler:] granted: %@", granted ? @"YES" : @"NO");
            [WonderPush refreshPreferencesAndConfiguration];
        }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
#pragma clang diagnostic pop
        });
    }
}

@end
