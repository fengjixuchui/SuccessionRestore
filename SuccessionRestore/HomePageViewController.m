//
//  ViewController.m
//  SuccessionRestore
//
//  Created by Sam Gardner on 9/27/17.
//  Copyright © 2017 Sam Gardner. All rights reserved.
//

#import "HomePageViewController.h"
#import "DownloadViewController.h"
#include <sys/sysctl.h>
#include <CoreFoundation/CoreFoundation.h>
#include <spawn.h>
#include <sys/stat.h>

@interface HomePageViewController ()

@end

@implementation HomePageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[[self navigationController] navigationBar] setHidden:TRUE];
    // Create a size_t and set it to the size used to allocate modelChar
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    
    //Gets iOS device model (ex iPhone9,1 == iPhone 7 GSM) and changes label.
    char *modelChar = malloc(size);
    sysctlbyname("hw.machine", modelChar, &size, NULL, 0);
    _deviceModel = [NSString stringWithUTF8String:modelChar];
    free(modelChar);
    self.deviceModelLabel.text = [NSString stringWithFormat:@"%@", _deviceModel];
    
    //Gets iOS version and changes label.
    _deviceVersion = [[UIDevice currentDevice] systemVersion];
    self.iOSVersionLabel.text = [NSString stringWithFormat:@"%@", _deviceVersion];
    
    // Set size to the size used to allocate buildChar
    sysctlbyname("kern.osversion", NULL, &size, NULL, 0);
    
    //Gets iOS device build number (ex 10.1.1 == 14B100 or 14B150) and changes label.
    //Thanks, Apple, for releasing two versions of 10.1.1, you really like making things hard on us.
    char *buildChar = malloc(size);
    sysctlbyname("kern.osversion", buildChar, &size, NULL, 0);
    _deviceBuild = [NSString stringWithUTF8String:buildChar];
    free(buildChar);
    self.iOSBuildLabel.text = [NSString stringWithFormat:@"%@", _deviceBuild];
    // Don't run on the 6s on 9.X due to activation issue
    if ([_deviceModel isEqualToString:@"iPhone8,1"] || [_deviceModel isEqualToString:@"iPhone8,2"]) {
        if ([_deviceVersion hasPrefix:@"9."]) {
            UIAlertController *activationError = [UIAlertController alertControllerWithTitle:@"Succession is disabled" message:@"Apple does not allow the iPhone 6s or 6s Plus to activate on iOS 9.X. Running succession would force you to restore to the latest version of iOS, and is therefore disabled. Sorry about that :/" preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *exitAction = [UIAlertAction actionWithTitle:@"Exit" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                exit(0);
            }];
            [activationError addAction:exitAction];
            [self presentViewController:activationError animated:TRUE completion:nil];
        }
    }
    // Don't run on unc0ver 4.0-4.2.X because of restore hang
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/libexec/pwnproxy"]) {
        UIAlertController *pwnproxyError = [UIAlertController alertControllerWithTitle:@"Succession is disabled" message:@"Succession is not compatible with unc0ver 4.0-4.2.1" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *exitAction = [UIAlertAction actionWithTitle:@"Exit" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            exit(0);
        }];
        [pwnproxyError addAction:exitAction];
        [self presentViewController:pwnproxyError animated:TRUE completion:nil];
    }
    // At launch, if both rfs.dmg and ipsw.ipsw exist, that probably means extraction failed, so delete rfs.dmg to force a retry
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/Media/Succession/ipsw.ipsw"] && [[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/Media/Succession/rfs.dmg"]) {
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Media/Succession/rfs.dmg" error:nil];
    }
    // Checks if the app has ever been run before
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist"]) {
        // Present an alert asking the user to consider donating.
        UIAlertController *pleaseGiveMoney = [UIAlertController alertControllerWithTitle:@"Please consider donating" message:@"This product is free, and I never intend to change that, but if it works for you, I please ask you to consider donating to my paypal to support future products." preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *giveMeMoney = [UIAlertAction actionWithTitle:@"Donate" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (@available(iOS 10.0, *)) {
                NSDictionary *URLOptions = @{UIApplicationOpenURLOptionUniversalLinksOnly : @FALSE};
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.me/SamGardner4"] options:URLOptions completionHandler:nil];
            } else {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.me/SamGardner4"]];
            }
            NSURLSessionDownloadTask *getMOTDTask = [[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]] downloadTaskWithURL:[NSURL URLWithString:@"https://raw.githubusercontent.com/Samgisaninja/samgisaninja.github.io/master/motd.plist"]];
            [getMOTDTask resume];
        }];
        UIAlertAction *giveMeMoneyLater = [UIAlertAction actionWithTitle:@"Not now" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            NSURLSessionDownloadTask *getMOTDTask = [[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]] downloadTaskWithURL:[NSURL URLWithString:@"https://raw.githubusercontent.com/Samgisaninja/samgisaninja.github.io/master/motd.plist"]];
            [getMOTDTask resume];
        }];
        [pleaseGiveMoney addAction:giveMeMoney];
        [pleaseGiveMoney addAction:giveMeMoneyLater];
        [self presentViewController:pleaseGiveMoney animated:TRUE completion:nil];
    } else {
        NSURLSessionDownloadTask *getMOTDTask = [[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]] downloadTaskWithURL:[NSURL URLWithString:@"https://raw.githubusercontent.com/Samgisaninja/samgisaninja.github.io/master/motd.plist"]];
        [getMOTDTask resume];
    }
    NSMutableDictionary *successionPrefs = [NSMutableDictionary dictionaryWithDictionary:[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist"]];
    if (![successionPrefs objectForKey:@"dry-run"]) {
        [successionPrefs setObject:@(0) forKey:@"dry-run"];
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" error:nil];
        [successionPrefs writeToFile:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" atomically:TRUE];
    }
    if (![successionPrefs objectForKey:@"update-install"]) {
        [successionPrefs setObject:@(0) forKey:@"update-install"];
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" error:nil];
        [successionPrefs writeToFile:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" atomically:TRUE];
    }
    if (![successionPrefs objectForKey:@"log-file"]) {
        [successionPrefs setObject:@(0) forKey:@"log-file"];
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" error:nil];
        [successionPrefs writeToFile:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" atomically:TRUE];
    }
    if (![successionPrefs objectForKey:@"hacktivation"]) {
        [successionPrefs setObject:@(0) forKey:@"hacktivation"];
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" error:nil];
        [successionPrefs writeToFile:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" atomically:TRUE];
    }
    if (![successionPrefs objectForKey:@"create_APFS_orig-fs"]) {
        [successionPrefs setObject:@(0) forKey:@"create_APFS_orig-fs"];
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" error:nil];
        [successionPrefs writeToFile:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" atomically:TRUE];
    }
    if (![successionPrefs objectForKey:@"create_APFS_succession-prerestore"]) {
        [successionPrefs setObject:@(0) forKey:@"create_APFS_succession-prerestore"];
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" error:nil];
        [successionPrefs writeToFile:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" atomically:TRUE];
    }
    if (![successionPrefs objectForKey:@"custom_rsync_path"]) {
        [successionPrefs setObject:@"/usr/bin/rsync" forKey:@"custom_rsync_path"];
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" error:nil];
        [successionPrefs writeToFile:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" atomically:TRUE];
    }
    if (![successionPrefs objectForKey:@"custom_ipsw_path"]) {
        [successionPrefs setObject:@"/var/mobile/Media/Succession/ipsw.ipsw" forKey:@"custom_ipsw_path"];
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" error:nil];
        [successionPrefs writeToFile:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" atomically:TRUE];
    }
    if (![successionPrefs objectForKey:@"unofficial_tethered_downgrade_compatibility"]) {
        [successionPrefs setObject:@(0) forKey:@"unofficial_tethered_downgrade_compatibility"];
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" error:nil];
        [successionPrefs writeToFile:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist" atomically:TRUE];
    }
}

- (void) viewDidAppear:(BOOL)animated{
    [[[self navigationController] navigationBar] setHidden:TRUE];
    //Checks to see if DMG has already been downloaded and sets buttons accordingly
    NSDictionary *successionPrefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.samgisaninja.SuccessionRestore.plist"];
    NSArray *contentsOfSuccessionFolder = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/var/mobile/Media/Succession/" error:nil];
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/Media/Succession/rfs.dmg"]) {
        [_downloadDMGButton setHidden:TRUE];
        [_downloadDMGButton setEnabled:FALSE];
        [_prepareToRestoreButton setHidden:FALSE];
        [_prepareToRestoreButton setEnabled:TRUE];
        [_decryptDMGButton setHidden:TRUE];
        [_decryptDMGButton setEnabled:FALSE];
        [_infoLabel setHidden:TRUE];
        for (NSString *file in contentsOfSuccessionFolder) {
            if (![file isEqualToString:@"rfs.dmg"]) {
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/var/mobile/Media/Succession/%@", file] error:nil];
            }
        }
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/Media/Succession/encrypted.dmg"]) {
        [_downloadDMGButton setHidden:TRUE];
        [_downloadDMGButton setEnabled:FALSE];
        [_prepareToRestoreButton setHidden:TRUE];
        [_prepareToRestoreButton setEnabled:FALSE];
        [_decryptDMGButton setHidden:FALSE];
        [_decryptDMGButton setEnabled:TRUE];
        [_infoLabel setHidden:TRUE];
        for (NSString *file in contentsOfSuccessionFolder) {
            if (![file isEqualToString:@"encrypted.dmg"]) {
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/var/mobile/Media/Succession/%@", file] error:nil];
            }
        }
    } else {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[successionPrefs objectForKey:@"custom_ipsw_path"]]) {
            UIAlertController *ipswDetected = [UIAlertController alertControllerWithTitle:@"IPSW detected!" message:@"Please go to the download page if you'd like to use the IPSW file you provided." preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil];
            [ipswDetected addAction:okAction];
            [self presentViewController:ipswDetected animated:TRUE completion:nil];
        } else {
            for (NSString *file in contentsOfSuccessionFolder) {
                if ([file containsString:@".ipsw"]) {
                    UIAlertController *ipswDetected = [UIAlertController alertControllerWithTitle:@"IPSW detected!" message:@"Please go to the download page if you'd like to use the IPSW file you provided." preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil];
                    [ipswDetected addAction:okAction];
                    [self presentViewController:ipswDetected animated:TRUE completion:nil];
                }
            }
        }
        [_downloadDMGButton setHidden:FALSE];
        [_downloadDMGButton setEnabled:TRUE];
        [_prepareToRestoreButton setHidden:TRUE];
        [_prepareToRestoreButton setEnabled:FALSE];
        [_decryptDMGButton setHidden:TRUE];
        [_decryptDMGButton setEnabled:FALSE];
        [_infoLabel setHidden:FALSE];
        [_infoLabel setText:[NSString stringWithFormat:@"Please download an IPSW\nSuccession can do this automatically (press 'Download clean Filesystem' below) or you can place an IPSW in %@", [successionPrefs objectForKey:@"custom_ipsw_path"]]];
    }
}

- (IBAction)contactSupportButton:(id)sender {
    UIAlertController *contactSupport = [UIAlertController alertControllerWithTitle:@"Contact Samg_is_a_Ninja" message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *twitterSupport = [UIAlertAction actionWithTitle:@"On Twitter" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //Opens a DM to my twitter
        if (@available(iOS 10.0, *)) {
            NSDictionary *URLOptions = @{UIApplicationOpenURLOptionUniversalLinksOnly : @FALSE};
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/messages/compose?recipient_id=1207116990248296448"] options:URLOptions completionHandler:nil];
        } else {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/messages/compose?recipient_id=1207116990248296448"]];
        }
    }];
    UIAlertAction *redditSupport = [UIAlertAction actionWithTitle:@"On Reddit" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //Opens a PM to my reddit
        if (@available(iOS 10.0, *)) {
            NSDictionary *URLOptions = @{UIApplicationOpenURLOptionUniversalLinksOnly : @FALSE};
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.reddit.com/message/compose/?to=samg_is_a_ninja"] options:URLOptions completionHandler:nil];
        } else {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.reddit.com/message/compose/?to=samg_is_a_ninja"]];
        }
    }];
    [contactSupport addAction:twitterSupport];
    [contactSupport addAction:redditSupport];
    [self presentViewController:contactSupport animated:TRUE completion:nil];
}

- (IBAction)donateButton:(id)sender {
    //Hey, someone actually decided to donate?! <3
    if (@available(iOS 10.0, *)) {
        NSDictionary *URLOptions = @{UIApplicationOpenURLOptionUniversalLinksOnly : @FALSE};
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.me/SamGardner4/"] options:URLOptions completionHandler:nil];
    } else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.me/SamGardner4/"]];
    }
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if ([segue.identifier isEqualToString:@"deviceInfoShare"]) {
        DownloadViewController *destViewController = segue.destinationViewController;
        destViewController.deviceVersion = _deviceVersion;
        destViewController.deviceModel = _deviceModel;
        destViewController.deviceBuild = _deviceBuild;
    }
}

- (IBAction)infoNotAccurateButton:(id)sender {
    //Code that runs the "Information not correct" button
    UIAlertController *infoNotAccurateButtonInfo = [UIAlertController alertControllerWithTitle:@"Please provide your own DMG" message:@"Please extract a clean IPSW for your device/iOS version and place the largest DMG file in /var/mobile/Media/Succession. On iOS 9.3.5 and older, you will need to decrypt the DMG first." preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [infoNotAccurateButtonInfo addAction:okAction];
    [self presentViewController:infoNotAccurateButtonInfo animated:YES completion:nil];
}

- (void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSDictionary *motd = [NSDictionary dictionaryWithContentsOfFile:[location path]];
    if ([[[motd objectForKey:@"all"] objectForKey:@"showMessage"] isEqual:@(1)]) {
        UIAlertController *motdAlert = [UIAlertController alertControllerWithTitle:@"Message" message:[[motd objectForKey:@"all"] objectForKey:@"messageContent"] preferredStyle:UIAlertControllerStyleAlert];
        if ([[[motd objectForKey:@"all"] objectForKey:@"warning"] isEqual: @(1)]) {
            if ([[[motd objectForKey:@"all"] objectForKey:@"disabled"] isEqual: @(1)]) {
                UIAlertAction *disabledAction = [UIAlertAction actionWithTitle:@"Exit" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    exit(0);
                }];
                [motdAlert addAction:disabledAction];
                [self presentViewController:motdAlert animated:TRUE completion:nil];
            } else {
                UIAlertAction *warningAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDestructive handler:nil];
                [motdAlert addAction:warningAction];
                [self presentViewController:motdAlert animated:TRUE completion:nil];
            }
            
        } else {
            UIAlertAction *dismissAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil];
            [motdAlert addAction:dismissAction];
            [self presentViewController:motdAlert animated:TRUE completion:nil];
        }
    }
    if ([[[[motd objectForKey:@"successionVersions"] objectForKey:[[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"]] objectForKey:@"showMessage"] isEqual:@(1)]) {
        UIAlertController *motdAlert = [UIAlertController alertControllerWithTitle:@"Message" message:[[[motd objectForKey:@"successionVersions"] objectForKey:[[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"]] objectForKey:@"messageContent"] preferredStyle:UIAlertControllerStyleAlert];
        if ([[[[motd objectForKey:@"successionVersions"] objectForKey:[[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"]] objectForKey:@"warning"] isEqual: @(1)]) {
            if ([[[[motd objectForKey:@"successionVersions"] objectForKey:[[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"]] objectForKey:@"disabled"] isEqual: @(1)]) {
                UIAlertAction *disabledAction = [UIAlertAction actionWithTitle:@"Exit" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    exit(0);
                }];
                [motdAlert addAction:disabledAction];
                [self presentViewController:motdAlert animated:TRUE completion:nil];
            } else {
                UIAlertAction *warningAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDestructive handler:nil];
                [motdAlert addAction:warningAction];
                [self presentViewController:motdAlert animated:TRUE completion:nil];
            }
            
        } else {
            UIAlertAction *dismissAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil];
            [motdAlert addAction:dismissAction];
            [self presentViewController:motdAlert animated:TRUE completion:nil];
        }
    }
    if ([[[[motd objectForKey:@"deviceModels"] objectForKey:_deviceModel] objectForKey:@"showMessage"] isEqual:@(1)]) {
        UIAlertController *motdAlert = [UIAlertController alertControllerWithTitle:@"Message" message:[NSString stringWithFormat:@"%@", [[[motd objectForKey:@"deviceModels"] objectForKey:_deviceModel] objectForKey:@"messageContent"]] preferredStyle:UIAlertControllerStyleAlert];
        if ([[[[motd objectForKey:@"deviceModels"] objectForKey:_deviceModel] objectForKey:@"warning"] isEqual: @(1)]) {
            if ([[[[motd objectForKey:@"deviceModels"] objectForKey:_deviceModel] objectForKey:@"disabled"] isEqual: @(1)]) {
                UIAlertAction *disabledAction = [UIAlertAction actionWithTitle:@"Exit" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    exit(0);
                }];
                [motdAlert addAction:disabledAction];
                [self presentViewController:motdAlert animated:TRUE completion:nil];
            } else {
                UIAlertAction *warningAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDestructive handler:nil];
                [motdAlert addAction:warningAction];
                [self presentViewController:motdAlert animated:TRUE completion:nil];
            }
            
        } else {
            UIAlertAction *dismissAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil];
            [motdAlert addAction:dismissAction];
            [self presentViewController:motdAlert animated:TRUE completion:nil];
        }
    }
    if ([[[[motd objectForKey:@"iOSVersions"] objectForKey:_deviceBuild] objectForKey:@"showMessage"] isEqual:@(1)]) {
        UIAlertController *motdAlert = [UIAlertController alertControllerWithTitle:@"Message" message:[[[motd objectForKey:@"iOSVersions"] objectForKey:_deviceBuild] objectForKey:@"messageContent"] preferredStyle:UIAlertControllerStyleAlert];
        if ([[[[motd objectForKey:@"iOSVersions"] objectForKey:_deviceBuild] objectForKey:@"warning"] isEqual: @(1)]) {
            if ([[[[motd objectForKey:@"iOSVersions"] objectForKey:_deviceBuild] objectForKey:@"disabled"] isEqual: @(1)]) {
                UIAlertAction *disabledAction = [UIAlertAction actionWithTitle:@"Exit" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    exit(0);
                }];
                [motdAlert addAction:disabledAction];
                [self presentViewController:motdAlert animated:TRUE completion:nil];
            } else {
                UIAlertAction *warningAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDestructive handler:nil];
                [motdAlert addAction:warningAction];
                [self presentViewController:motdAlert animated:TRUE completion:nil];
            }
            
        } else {
            UIAlertAction *dismissAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil];
            [motdAlert addAction:dismissAction];
            [self presentViewController:motdAlert animated:TRUE completion:nil];
        }
    }
}

@end

