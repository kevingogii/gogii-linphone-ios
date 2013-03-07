/* LinphoneAppDelegate.m
 *
 * Copyright (C) 2009  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or   
 *  (at your option) any later version.                                 
 *                                                                      
 *  This program is distributed in the hope that it will be useful,     
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of      
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       
 *  GNU General Public License for more details.                
 *                                                                      
 *  You should have received a copy of the GNU General Public License   
 *  along with this program; if not, write to the Free Software         
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */                                                                           

#import "PhoneMainView.h"
#import "linphoneAppDelegate.h"
#import "AddressBook/ABPerson.h"

#import "CoreTelephony/CTCallCenter.h"
#import "CoreTelephony/CTCall.h"

#import "ConsoleViewController.h"
#import "LinphoneCoreSettingsStore.h"

#include "LinphoneManager.h"
#include "linphonecore.h"

@implementation UILinphoneWindow

@end

@implementation LinphoneAppDelegate

@synthesize started;


#pragma mark - Lifecycle Functions

- (id)init {
    self = [super init];
    if(self != nil) {
        self->started = FALSE;
    }
    return self;
}

- (void)dealloc {
	[super dealloc];
}


#pragma mark - 



- (void)applicationDidEnterBackground:(UIApplication *)application{
	[LinphoneLogger logc:LinphoneLoggerLog format:"applicationDidEnterBackground"];
	if(![LinphoneManager isLcReady]) return;
	[[LinphoneManager instance] enterBackgroundMode];
}

- (void)applicationWillResignActive:(UIApplication *)application {
	[LinphoneLogger logc:LinphoneLoggerLog format:"applicationWillResignActive"];
    if(![LinphoneManager isLcReady]) return;
    LinphoneCore* lc = [LinphoneManager getLc];
    LinphoneCall* call = linphone_core_get_current_call(lc);
	
	
    if (call){
		/* save call context */
		LinphoneManager* instance = [LinphoneManager instance];
		instance->currentCallContextBeforeGoingBackground.call = call;
		instance->currentCallContextBeforeGoingBackground.cameraIsEnabled = linphone_call_camera_enabled(call);
    
		const LinphoneCallParams* params = linphone_call_get_current_params(call);
		if (linphone_call_params_video_enabled(params)) {
			linphone_call_enable_camera(call, false);
		}
	}
    
    if (![[LinphoneManager instance] resignActive]) {

    }
    
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	[LinphoneLogger logc:LinphoneLoggerLog format:"applicationDidBecomeActive"];
    [self startApplication];
    
	[[LinphoneManager instance] becomeActive];
    
    
    LinphoneCore* lc = [LinphoneManager getLc];
    LinphoneCall* call = linphone_core_get_current_call(lc);
    
	if (call){
		LinphoneManager* instance = [LinphoneManager instance];
		if (call == instance->currentCallContextBeforeGoingBackground.call) {
			const LinphoneCallParams* params = linphone_call_get_current_params(call);
			if (linphone_call_params_video_enabled(params)) {
				linphone_call_enable_camera(
                                        call, 
                                        instance->currentCallContextBeforeGoingBackground.cameraIsEnabled);
			}
			instance->currentCallContextBeforeGoingBackground.call = 0;
		}
	}
}



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeSound|UIRemoteNotificationTypeBadge];
    
	//work around until we can access lpconfig without linphonecore
	NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"YES", @"start_at_boot_preference",
								 @"YES", @"backgroundmode_preference",
#ifdef DEBUG
								 @"YES",@"debugenable_preference",
#else
								 @"NO",@"debugenable_preference",
#endif
                                 nil];
	[[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
	
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]
		&& [UIApplication sharedApplication].applicationState ==  UIApplicationStateBackground
        && (![[NSUserDefaults standardUserDefaults] boolForKey:@"start_at_boot_preference"] ||
            ![[NSUserDefaults standardUserDefaults] boolForKey:@"backgroundmode_preference"])) {
            // autoboot disabled, doing nothing
            return YES;
        }
    
    [self startApplication];
	NSDictionary *remoteNotif =[launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (remoteNotif){
		[LinphoneLogger log:LinphoneLoggerLog format:@"PushNotification from launch received."];
		[self processRemoteNotification:remoteNotif];
	}
    else if ([launchOptions objectForKey:UIApplicationLaunchOptionsURLKey])
    {
        [self application:application handleOpenURL:[launchOptions objectForKey:UIApplicationLaunchOptionsURLKey]];
    }
    return YES;
}

- (void)startApplication {
    // Restart Linphone Core if needed
    if(![LinphoneManager isLcReady]) {
        [[LinphoneManager instance]	startLibLinphone];
    }
    if([LinphoneManager isLcReady]) {
        
        
        // Only execute one time at application start
        if(!started) {
            started = TRUE;
            [[PhoneMainView instance] startUp];
        }
    }
}


- (void)applicationWillTerminate:(UIApplication *)application {
	
}
-(NSMutableDictionary*)dictionaryParamFromAppLaunchURL:(NSURL*)url
{
    NSArray* queryComponents = [[url query] componentsSeparatedByString:@"&"];
    NSArray* keyValComponents;
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithCapacity:[queryComponents count]];
    for (NSString* keyVal in queryComponents) {
        keyValComponents = [keyVal componentsSeparatedByString:@"="];
        [params setObject:[keyValComponents objectAtIndex:1] forKey:[keyValComponents objectAtIndex:0]];
    }
    return params;
}
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    [self startApplication];
    if([LinphoneManager isLcReady]) {
        if([[url scheme] isEqualToString:@"sip"]) {
            // Go to ChatRoom view
            DialerViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[DialerViewController compositeViewDescription]], DialerViewController);
            if(controller != nil) {
                [controller setAddress:[url absoluteString]];
            }
        }
        else if([[url scheme] isEqualToString:@"gp"] && [[url host] isEqualToString:@"account"]) {
            //globephone setup URL
            NSString* username = nil, *password = nil, *domain = nil, *server = nil, *port = nil;
            NSDictionary* paramDict = [self dictionaryParamFromAppLaunchURL:url];
            username = [paramDict objectForKey:@"sip_username"];
            password = [paramDict objectForKey:@"sip_password"];
            domain = [paramDict objectForKey:@"sip_realm"];
            server = [paramDict objectForKey:@"sip_proxy"];
            port = [paramDict objectForKey:@"sip_port"];
            
            //set sip info
            LinphoneCore *lc = [LinphoneManager getLc];
            linphone_core_clear_proxy_config([LinphoneManager getLc]);
            linphone_core_clear_all_auth_info([LinphoneManager getLc]);
            char normalizedUserName[256];
            if (port) {
                linphone_core_set_sip_port([LinphoneManager getLc], [port intValue]);
            }
            LinphoneAddress* linphoneAddress = linphone_address_new(linphone_core_get_identity(lc));
            linphone_proxy_config_normalize_number(NULL, [username cStringUsingEncoding:[NSString defaultCStringEncoding]], normalizedUserName, sizeof(normalizedUserName));
            linphone_address_set_username(linphoneAddress, normalizedUserName);
            linphone_address_set_domain(linphoneAddress, [domain UTF8String]);
            const char* identity = linphone_address_as_string_uri_only(linphoneAddress);
            LinphoneProxyConfig* proxyCfg = linphone_core_create_proxy_config([LinphoneManager getLc]);
            LinphoneAuthInfo* info = linphone_auth_info_new([username UTF8String], NULL, [password UTF8String], NULL, NULL);
            linphone_proxy_config_set_identity(proxyCfg, identity);
            linphone_proxy_config_set_server_addr(proxyCfg, [server UTF8String]);
            if([server compare:domain options:NSCaseInsensitiveSearch] != 0) {
                linphone_proxy_config_set_route(proxyCfg, [server UTF8String]);
            }
            int defaultExpire = [[LinphoneManager instance] lpConfigIntForKey:@"default_expires"];
            if (defaultExpire >= 0)
                linphone_proxy_config_expires(proxyCfg, defaultExpire);
            linphone_proxy_config_enable_register(proxyCfg, true);
            linphone_core_add_proxy_config([LinphoneManager getLc], proxyCfg);
            linphone_core_set_default_proxy([LinphoneManager getLc], proxyCfg);
            linphone_core_add_auth_info([LinphoneManager getLc], info);
            
        }
        else if([[url scheme] isEqualToString:@"gp"] && [[url host] isEqualToString:@"dial"]) {
            NSString* phoneNumber = [url query];
            if (phoneNumber) {
                DialerViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[DialerViewController compositeViewDescription]], DialerViewController);
                if(controller != nil) {
                    [controller setAddress:[url query]];
                }
            }
        }
    }
	return YES;
}

- (void)processRemoteNotification:(NSDictionary*)userInfo{
	NSDictionary *aps = [userInfo objectForKey:@"aps"];
    if(aps != nil) {
        NSDictionary *alert = [aps objectForKey:@"alert"];
        if(alert != nil) {
            NSString *loc_key = [alert objectForKey:@"loc-key"];
			/*if we receive a remote notification, it is because our TCP background socket was no more working.
			 As a result, break it and refresh registers in order to make sure to receive incoming INVITE or MESSAGE*/
			LinphoneCore *lc = [LinphoneManager getLc];
			linphone_core_set_network_reachable(lc, FALSE);
			linphone_core_set_network_reachable(lc, TRUE);
            if(loc_key != nil) {
                if([loc_key isEqualToString:@"IM_MSG"]) {
                    [[PhoneMainView instance] addInhibitedEvent:kLinphoneTextReceived];
                    [[PhoneMainView instance] changeCurrentView:[ChatViewController compositeViewDescription]];
                } else if([loc_key isEqualToString:@"IC_MSG"]) {
                    //it's a call
					NSString *callid=[userInfo objectForKey:@"call-id"];
                    if (callid)
						[[LinphoneManager instance] enableAutoAnswerForCallId:callid];
					else
						[LinphoneLogger log:LinphoneLoggerError format:@"PushNotification: does not have call-id yet, fix it !"];
                }
            }
        }
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
	[LinphoneLogger log:LinphoneLoggerLog format:@"PushNotification: Receive %@", userInfo];
	[self processRemoteNotification:userInfo];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    if([notification.userInfo objectForKey:@"callId"] != nil) {
        [[LinphoneManager instance] acceptCallForCallId:[notification.userInfo objectForKey:@"callId"]];
    } else if([notification.userInfo objectForKey:@"chat"] != nil) {
        NSString *remoteContact = (NSString*)[notification.userInfo objectForKey:@"chat"];
        // Go to ChatRoom view
        [[PhoneMainView instance] changeCurrentView:[ChatViewController compositeViewDescription]];
        ChatRoomViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[ChatRoomViewController compositeViewDescription] push:TRUE], ChatRoomViewController);
        if(controller != nil) {
            [controller setRemoteAddress:remoteContact];
        }
    } else if([notification.userInfo objectForKey:@"callLog"] != nil) {
        NSString *callLog = (NSString*)[notification.userInfo objectForKey:@"callLog"];
        // Go to HistoryDetails view
        [[PhoneMainView instance] changeCurrentView:[HistoryViewController compositeViewDescription]];
        HistoryDetailsViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[HistoryDetailsViewController compositeViewDescription] push:TRUE], HistoryDetailsViewController);
        if(controller != nil) {
            [controller setCallLogId:callLog];
        }
    }
}


#pragma mark - PushNotification Functions

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken {
    [LinphoneLogger log:LinphoneLoggerLog format:@"PushNotification: Token %@", deviceToken];
    [[LinphoneManager instance] setPushNotificationToken:deviceToken];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error {
    [LinphoneLogger log:LinphoneLoggerError format:@"PushNotification: Error %@", [error localizedDescription]];
    [[LinphoneManager instance] setPushNotificationToken:nil];
}

@end
