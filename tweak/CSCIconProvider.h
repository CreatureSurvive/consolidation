enum {
    CSCIconStyleSmall = 0,
    CSCIconStyleMedium = 1,
    CSCIconStyleRegular = 2,
    CSCIconStyleDocumentSmallUnmasked = 3,
    CSCIconStyleDocumentSmallMasked = 4,
    CSCIconStyleTiny = 5,
    CSCIconStyleLarge = 8,
    CSCIconStyleDocumentMediumUnmasked = 11,
    CSCIconStyleDocumentLargeUnmasked = 12,
};
typedef NSUInteger CSCIconStyle;

@interface SBIcon
- (UIImage *)getIconImage:(NSInteger)style;
@end

@interface SBIconModel : NSObject
- (SBIcon *)applicationIconForBundleIdentifier:(NSString *)identifier;
@end

@interface SBIconController : UIViewController
+ (id)sharedInstance;
- (SBIconModel *)model;
@end

@interface CSCIconProvider : NSObject
+ (instancetype)sharedProvider;
+ (UIImage *)iconForBundleIdentifier:(NSString *)identifier;

- (UIImage *)iconForBundleIdentifier:(NSString *)identifier;
- (UIImage *)iconOfStyle:(CSCIconStyle)style forIdentifier:(NSString *)identifier;
- (void)cacheIconForFailsafe:(UIImage *)icon forKey:(NSString *)key;
@end