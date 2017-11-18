#include "CSCIconProvider.h"

@implementation CSCIconProvider {
    NSCache *_failsafeIconCache;
    SBIconModel *_model;
}

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

- (UIImage *)iconForBundleIdentifier:(NSString *)identifier {
    return [self iconOfStyle:CSCIconStyleRegular forIdentifier:identifier];
}

- (UIImage *)iconOfStyle:(CSCIconStyle)style forIdentifier:(NSString *)identifier {
    if (!_model) {
        SBIconController *iconController = [NSClassFromString(@"SBIconController") sharedInstance];
        _model = [iconController model];
    }

    SBIcon *icon = [_model applicationIconForBundleIdentifier:identifier];
    UIImage *iconImage = [icon getIconImage:style] ? : [self _failsafeIconForKey:identifier];
    return iconImage;
}

- (void)cacheIconForFailsafe:(UIImage *)icon forKey:(NSString *)key {
    if (!_failsafeIconCache) {
        _failsafeIconCache = [NSCache new];
    }
    if ([_failsafeIconCache objectForKey:key]) return;

    if ([key isEqualToString:@"com.apple.DuetHeuristic-BM"]) {
        icon = [UIImage imageNamed:@"BatteryIcon" inBundle:[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/DuetHeuristics.framework"] compatibleWithTraitCollection:nil];
    }

    if ([key isEqualToString:@"-showAll"]) {
        icon = [UIImage imageNamed:@"ReaderButton" inBundle:[NSBundle bundleWithPath:@"/System/Library/Frameworks/SafariServices.framework"] compatibleWithTraitCollection:nil];
    }

    [_failsafeIconCache setObject:icon forKey:key];
}

- (UIImage *)_failsafeIconForKey:(NSString *)key {
    if (!_failsafeIconCache) return nil;
    return [_failsafeIconCache objectForKey:key] ? : nil;
}

@end