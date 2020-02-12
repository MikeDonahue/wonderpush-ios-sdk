/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#import <Foundation/Foundation.h>

// We can't import WPLog.h from here, because it is packaged in 2 podspecs and not in the same directory as this file.
void WPLogDebug(NSString *format, ...);
void WPLog(NSString *format, ...);

// this should eventually be in WPError.h
extern NSString *const kWonderPushInAppMessagingErrorDomain;

// InAppMessaging doesn't provide any functionality to other components,
// so it provides a private, empty protocol that it conforms to and use it for registration.

@protocol WPInAppMessagingInstanceProvider
@end
