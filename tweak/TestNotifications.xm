#import "TestNotifications.h"
#include <dlfcn.h>
extern dispatch_queue_t __BBServerQueue;

BBServer *bbServer = nil;

static const NSUInteger kNotificationCenterDestination = 2;
static const NSUInteger kLockScreenDestination = 4;


static NSUInteger bulletinNum = 0;

// Must be invoked on the BBServerQueue!
static NSString *nextBulletinID() {
    ++bulletinNum;
    return [NSString stringWithFormat:@"com.creaturecoding.consolidation.notification-id-%@", @(bulletinNum)];
}

// Must be invoked on the BBServerQueue!
static void sendTestNotification(BBServer *server, NSUInteger destinations, BOOL toLS) {
    NSString *bulletinID = nextBulletinID();
    BBBulletinRequest *bulletin = [[%c(BBBulletinRequest) alloc] init];
    bulletin.title = @"Consolidation ALPHA";
    bulletin.message = @"This is a test notification!";
    bulletin.sectionID = @"com.apple.MobileSMS";
    bulletin.recordID = bulletinID;
    bulletin.publisherBulletinID = bulletinID;
    bulletin.clearable = YES;
    bulletin.showsMessagePreview = YES;
    NSDate *date = [NSDate date];
    bulletin.date = date;
    bulletin.publicationDate = date;
    bulletin.lastInterruptDate = date;

    NSURL *url = [NSURL URLWithString:@"prefs:root=Consolidation"];
    bulletin.defaultAction = [%c(BBAction) actionWithLaunchURL:url];

    if ([server respondsToSelector:@selector(publishBulletinRequest:destinations:alwaysToLockScreen:)]) {
        [server publishBulletinRequest:bulletin destinations:destinations alwaysToLockScreen:toLS];
    }
}

static void showTestLockScreenNotification() {
    if (!bbServer) {
        return;
    }

    [[%c(SBLockScreenManager) sharedInstance] lockUIFromSource:1 withOptions:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.7 * NSEC_PER_SEC), __BBServerQueue, ^{
        sendTestNotification(bbServer, kLockScreenDestination, YES);
    });
}

static void showTestNotificationCenterNotification() {
    if (!bbServer) {
        return;
    }

    [[%c(SBNotificationCenterController) sharedInstance] presentAnimated:YES];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.7 * NSEC_PER_SEC), __BBServerQueue, ^{
        sendTestNotification(bbServer, kNotificationCenterDestination, NO);
    });
}

%hook BBServer

- (id)init {
    bbServer = %orig;
    return bbServer;
}

%end

%ctor {

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)showTestNotificationCenterNotification, CFSTR("com.creaturecoding.consolidation-testnotification-nc"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)showTestLockScreenNotification, CFSTR("com.creaturecoding.consolidation-testnotification-ls"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}