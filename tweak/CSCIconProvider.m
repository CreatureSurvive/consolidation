#include "CSCIconProvider.h"

@implementation CSCIconProvider {
    NSCache *_failsafeIconCache;
    SBIconModel *_model;
}

#pragma mark - Class Methods

+ (instancetype)sharedProvider {
    static dispatch_once_t once;
    static id sharedProvider;
    dispatch_once(&once, ^{
        sharedProvider = [[self alloc] init];
    });
    return sharedProvider;
}

+ (UIImage *)iconForBundleIdentifier:(NSString *)identifier {
    SBIconController *iconController = [NSClassFromString(@"SBIconController") sharedInstance];
    SBIconModel *model = [iconController model];
    SBIcon *icon = [model applicationIconForBundleIdentifier:identifier];
    return [icon getIconImage:2];
}

#pragma mark - Instance Methods

- (UIImage *)iconForBundleIdentifier:(NSString *)identifier {
    return [self iconOfStyle:CSCIconStyleRegular forIdentifier:identifier];
}

- (UIImage *)iconOfStyle:(CSCIconStyle)style forIdentifier:(NSString *)identifier {

    UIImage *iconImage = [self _failsafeIconForKey:identifier];
    if (iconImage) return iconImage;

    if (!_model) {
        SBIconController *iconController = [NSClassFromString(@"SBIconController") sharedInstance];
        _model = [iconController model];
    }

    SBIcon *icon = [_model applicationIconForBundleIdentifier:identifier];
    iconImage = [icon getIconImage:style] ? : [self _nonAppIconForKey:identifier];

    [self cacheIconForFailsafe:iconImage forKey:identifier];

    return iconImage;
}

- (void)cacheIconForFailsafe:(UIImage *)icon forKey:(NSString *)key {
    if (!_failsafeIconCache) {
        _failsafeIconCache = [NSCache new];
    }

    if ([_failsafeIconCache objectForKey:key]) return;

    [_failsafeIconCache setObject:icon forKey:key];
}

#pragma mark - Private Methods

- (UIImage *)_failsafeIconForKey:(NSString *)key {
    if (!_failsafeIconCache) return nil;
    return [_failsafeIconCache objectForKey:key] ? : nil;
}

- (UIImage *)_nonAppIconForKey:(NSString *)key {
    UIImage *icon;

    if ([key isEqualToString:@"com.apple.springboard.SBUserNotificationAlert"]) {
        icon = [UIImage imageWithContentsOfFile:@"/System/Library/PrivateFrameworks/PassKitUI.framework/Payment_AlertAccessory@2x.png"];
    }

    if ([key isEqualToString:@"com.apple.DuetHeuristic-BM"]) {
        icon = [UIImage imageNamed:@"BatteryIcon" inBundle:[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/DuetHeuristics.framework"] compatibleWithTraitCollection:nil];
    }

    if ([key isEqualToString:@"-showAll"]) {
        icon = [UIImage imageNamed:@"ReaderButton" inBundle:[NSBundle bundleWithPath:@"/System/Library/Frameworks/SafariServices.framework"] compatibleWithTraitCollection:nil];
    }

    if ([key isEqualToString:@"-calendarForLockscreen"]) {
        icon = [self iconForBundleIdentifier:@"com.apple.mobilecal"];
    }

    if (!icon) {
        icon = [UIImage imageWithContentsOfFile:@"/System/Library/PrivateFrameworks/PassKitUI.framework/Payment_Alert@2x.png"];
    }

    return icon;
}

@end