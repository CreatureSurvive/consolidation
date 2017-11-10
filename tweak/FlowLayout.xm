#import "Headers.h"
#import "CSCProvider.h"

#define prefs [CSCProvider sharedProvider]

//
// ___ NCNotificationListCollectionViewFlowLayout _________________________________
//

%hook NCNotificationListCollectionViewFlowLayout

%new - (BOOL)isLockscreenLayout {
    return [self.collectionView.delegate isKindOfClass:%c(NCNotificationPriorityListViewController)];
}

%new - (BOOL)isConsolidationEnabledForLayout {
    return [self isLockscreenLayout] ? [prefs boolForKey:@"enabled"] : [prefs boolForKey:@"ncEnabled"];
}

- (void)setMinimumLineSpacing:(double)spacing {
    if ([self isConsolidationEnabledForLayout]) {
        spacing = 0;
    }
    %orig(spacing);
}

- (void)setHeaderReferenceSize:(CGSize)size {
    if ([self isConsolidationEnabledForLayout]) {
        size = CGSizeZero;
    }
    %orig(size);
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSArray *attributes = %orig;
    if (![self isConsolidationEnabledForLayout])
        return attributes;

    NCNotificationListViewController *controller = (NCNotificationListViewController *)self.collectionView.delegate;
    for (UICollectionViewLayoutAttributes *attribute in attributes) {

        // if (attribute.representedElementCategory != UICollectionElementCategoryCell)
        //     continue;

        if (![controller shouldShowNotificationAtIndexPath:attribute.indexPath]) {
            attribute.hidden = YES;
            // attribute.size = CGSizeMake(0.1, 0.1);// does not seam to work with zero or 1 as size, this setting is ignored?
            // attribute.frame = CGRectMake(0.1, 0.1);// does not seam to work with zero or 1 as size, this setting is ignored?
        } else {
            attribute.center = CGPointMake(controller.collectionView.center.x, attribute.center.y);
            attribute.frame = CGRectMake(attribute.frame.origin.x, attribute.frame.origin.y + 8, attribute.size.width, attribute.size.height - 8);
        }
    }
    return attributes;
}

%end