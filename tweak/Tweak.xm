#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <AppList/AppList.h>
#import "substrate.h"
#import "Headers.h"
#import "PHPullToClearView.h"
#import "CSCProvider.h"
#import "CSCCollectionViewController.h"
#import "CSCIconProvider.h"

#define prefs [CSCProvider sharedProvider]
#define IN_LS [self isKindOfClass:%c(NCNotificationPriorityListViewController)]
#define ENABLED ((IN_LS && [prefs boolForKey:@"enabled"]) || (!IN_LS && [prefs boolForKey:@"ncEnabled"]))

PHPullToClearView *lsPullToClearView = nil;
PHPullToClearView *ncPullToClearView = nil;
NCNotificationPriorityListViewController *lsViewController = nil;
NCNotificationSectionListViewController *ncViewController = nil;
CSCCollectionViewController *lsIconCollection = nil;
CSCCollectionViewController *ncIconCollection = nil;

CGSize appViewSize(BOOL lockscreen) {
    if ((lockscreen && ![prefs boolForKey:@"enabled"]) || (!lockscreen && ![prefs boolForKey:@"ncEnabled"]))
        return CGSizeZero;

    CGFloat width = 0;
    NSInteger iconSize = (lockscreen) ? [prefs intForKey:@"iconSize"] : [prefs intForKey:@"ncIconSize"];

    switch (iconSize) {
        default:
        case 0:
            width = 30;
            break;
        case 1:
            width = 40;
            break;
        case 2:
            width = 50;
            break;
        case 3:
            width = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 106 : 84;
            break;
    }

    BOOL numberStyleBelow = lockscreen ? [prefs intForKey:@"numberStyle"] == 1 : [prefs boolForKey:@"ncNumberStyle"] == 1;
    CGFloat height = numberStyleBelow ? width * 1.5 : width;
    return CGSizeMake(width, height);
}

//
// ___ NCNotificationListCell _____________________________________________________
//

%hook NCNotificationListCell
%property(nonatomic, assign) BOOL scrolledOnce;

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    %orig;
    self.scrolledOnce = YES;
}

- (void)prepareForReuse {
    %orig;
    self.scrolledOnce = NO;
}

%end

//
// ___ NCNotificationListViewController ___________________________________________
//

%hook NCNotificationListViewController
%property(nonatomic, retain) NSString *selectedAppID;
%property(nonatomic, retain) NSMutableArray *sellectedNotifications;
// %property(nonatomic, retain) NSMutableDictionary *recentlyClearedNotifications;

// //potential fix for unlock prompt
- (void)notificationListCell:(NCNotificationListCell *)cell requestsPerformAction:(id)arg2 forNotificationRequest:(id)arg3 completion:(id)arg4  {
    if (ENABLED && !cell.scrolledOnce) return;
    %orig;
}

- (CGSize)collectionView:(UICollectionView *)collection layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGSize itemSize = %orig;
    if (!ENABLED) return itemSize;
    return [self shouldShowNotificationAtIndexPath:indexPath] ? CGSizeMake(itemSize.width, itemSize.height + 8) : CGSizeMake(0.1, 0.1);
}

- (void)viewDidLoad {
    %orig;
    [[CSCIconProvider sharedProvider] cacheIconForFailsafe:nil forKey:@"-showAll"];
    // self.recentlyClearedNotifications = [NSMutableDictionary new];

    if (IN_LS) {
        lsViewController = (NCNotificationPriorityListViewController *)self;
    } else {
        ncViewController = (NCNotificationSectionListViewController *)self;
    }
    if (IN_LS && !lsIconCollection) {
        lsIconCollection = [CSCCollectionViewController new];
        lsIconCollection.view.translatesAutoresizingMaskIntoConstraints = NO;
        lsIconCollection.cellSize = appViewSize(YES);
        lsIconCollection.collectionStyle = 0;
        [self addChildViewController:lsIconCollection];
        [self.view addSubview:lsIconCollection.view];
    } else if (!IN_LS && !ncIconCollection) {
        ncIconCollection = [CSCCollectionViewController new];
        ncIconCollection.view.translatesAutoresizingMaskIntoConstraints = NO;
        ncIconCollection.cellSize = appViewSize(NO);
        lsIconCollection.collectionStyle = 1;
        [self addChildViewController:ncIconCollection];
        [self.view addSubview:ncIconCollection.view];
    }

    // Create the pull to clear view
    if (!(IN_LS ? lsPullToClearView : ncPullToClearView)) {
        (IN_LS ? lsPullToClearView : ncPullToClearView) = [[PHPullToClearView alloc] initWithStyle:!(IN_LS)];
        [self.collectionView addSubview:((IN_LS) ? lsPullToClearView : ncPullToClearView)];
    }

    //sets the block methods for the pulltoclear and container views
    [self setupBlocks];
    (IN_LS ? lsPullToClearView : ncPullToClearView).hidden = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateConsolidationConstraintsAndLayout:) name:@"kCSCPrefsChanged" object:@YES];
}

- (void)viewWillLayoutSubviews {
    %orig;

    if (!ENABLED) {
        self.collectionView.frame = self.view.bounds;
        self.collectionView.translatesAutoresizingMaskIntoConstraints = YES;
        return;
    }

    [self updateConsolidationConstraintsAndLayout:NO];
}

// pull to clear update
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig;
    if (!ENABLED || self.selectedAppID == nil) return;
    [((IN_LS) ? lsPullToClearView : ncPullToClearView) didScroll:scrollView];
}

// pull to clear trigger
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    %orig;
    if (!ENABLED) return;
    [((IN_LS) ? lsPullToClearView : ncPullToClearView) didEndDragging:scrollView];
}

%new - (void)updateConsolidationConstraintsAndLayout: (BOOL)layout {
    self.collectionView.clipsToBounds = YES;
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;

    (IN_LS ? lsIconCollection : ncIconCollection).cellSize = appViewSize(IN_LS);

    // Layout container view
    BOOL onTop = ![prefs boolForKey:IN_LS ? @"iconLocation" : @"ncIconLocation"];
    CGFloat height = appViewSize((IN_LS)).height + 2;
    CGFloat top = onTop ? height : 0, bottom = !onTop ? -(height + 8) : 0;

    NSLayoutConstraint *edgeConstraint = onTop ? [NSLayoutConstraint constraintWithItem:(IN_LS ? lsIconCollection.view : ncIconCollection.view) attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0] :
                                         [NSLayoutConstraint constraintWithItem:(IN_LS ? lsIconCollection.view : ncIconCollection.view) attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-4.0];
    [self.view addConstraints:@[
         [NSLayoutConstraint constraintWithItem:self.collectionView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:self.collectionView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:self.collectionView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1 constant:bottom],
         [NSLayoutConstraint constraintWithItem:self.collectionView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:top],

         [NSLayoutConstraint constraintWithItem:(IN_LS ? lsIconCollection.view : ncIconCollection.view) attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:(IN_LS ? lsIconCollection.view : ncIconCollection.view) attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:(IN_LS ? lsIconCollection.view : ncIconCollection.view) attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:height],
         edgeConstraint
     ]];

    // Layout pull to clear view
    BOOL pullToClearEnabled = (IN_LS) ? [prefs boolForKey:@"enablePullToClear"] : [prefs boolForKey:@"ncEnablePullToClear"];
    CGRect currentFrame = ((IN_LS) ? lsPullToClearView : ncPullToClearView).frame;
    (IN_LS ? lsPullToClearView : ncPullToClearView).frame = CGRectMake(0, -(pullToClearSize + 8), self.collectionView.bounds.size.width, pullToClearSize);
    (IN_LS ? lsPullToClearView : ncPullToClearView).bounds = CGRectMake(CGRectGetMidX(currentFrame) - (pullToClearSize / 2), CGRectGetMidY(currentFrame) - (pullToClearSize / 2), pullToClearSize, pullToClearSize);
    (IN_LS ? lsPullToClearView : ncPullToClearView).hidden = !(pullToClearEnabled && ENABLED);

    if (layout) {
        [self.view layoutIfNeeded];
        [self.collectionView setNeedsLayout];
        [self.collectionView layoutIfNeeded];
        [(IN_LS ? lsIconCollection : ncIconCollection).view setNeedsLayout];
        [(IN_LS ? lsIconCollection : ncIconCollection).view layoutIfNeeded];
    }
}

// update for new notifications
%new - (void)insertOrModifyNotification: (NCNotificationRequest *)request {
    if (!ENABLED) return;

    [[CSCIconProvider sharedProvider] cacheIconForFailsafe:[[request content] icon] forKey:[request sectionIdentifier]];
    IN_LS ? [lsIconCollection updateContent] : [ncIconCollection updateContent];

    if (![prefs boolForKey:@"privacyMode"]) {
        [lsIconCollection selectItemWithIdentifier:[request sectionIdentifier] animated:YES];
    }
}

%new - (void)removeNotification: (NCNotificationRequest *)request {
    if (!ENABLED) return;

    IN_LS ? [lsIconCollection updateContent] : [ncIconCollection updateContent];
}

%new - (void)setupBlocks {

    (IN_LS ? lsIconCollection : ncIconCollection).allNotifications = ^NSArray *(){
        NSMutableArray *notifications = [NSMutableArray new];
        for (NSInteger section = 0; section < [self numberOfSectionsInCollectionView:self.collectionView]; section++) {
            for (NSInteger item = 0; item < [self collectionView:self.collectionView numberOfItemsInSection:section]; item++) {
                [notifications addObject:[self notificationRequestAtIndexPath:[NSIndexPath indexPathForRow:item inSection:section]]];
            }
        }
        return notifications;
    };

    (IN_LS ? lsIconCollection : ncIconCollection).setCurrentIdentifier = ^void (NSString *identifier) {
        self.selectedAppID = identifier;
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView setContentOffset:CGPointZero animated:NO];

        // Hide pull to clear view if no app is selected
        (IN_LS ? lsPullToClearView : ncPullToClearView).hidden = identifier == nil;

        NSDictionary *userInfo = @{
            @"isShowingNotifications": @(identifier != nil),
            @"isShowingNotificationsLS": IN_LS ? @(identifier != nil) : @NO,
            @"isShowingNotificationsNC": !IN_LS ? @(identifier != nil) : @NO,
        };
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kCSCShowingNotifications" object:nil userInfo:userInfo];
    };

    ((IN_LS) ? lsPullToClearView : ncPullToClearView).clearBlock = ^void () {
        BOOL clearAll = [self.selectedAppID isEqualToString:@"-showAll"] || [prefs boolForKey:(IN_LS) ? @"showAllWhenNotSelected" : @"ncshowAllWhenNotSelected"];
        self.sellectedNotifications = [NSMutableArray new];
        for (NSInteger section = 0; section < [self numberOfSectionsInCollectionView:self.collectionView]; section++) {
            for (NSInteger item = 0; item < [self collectionView:self.collectionView numberOfItemsInSection:section]; item++) {
                NCNotificationRequest *request = [self notificationRequestAtIndexPath:[NSIndexPath indexPathForRow:item inSection:section]];
                if (!clearAll && ![[request sectionIdentifier] isEqualToString:self.selectedAppID]) continue;
                [self.sellectedNotifications addObject:request];
                // [self.recentlyClearedNotifications setObject:request forKey:[NSString stringWithFormat:@"%ld-%ld", (long)item, (long)section]];
            }
        }
        [(IN_LS ? lsIconCollection : ncIconCollection) selectItemWithIdentifier:nil animated:NO];
        [self removeNotifications];
    };
}

%new - (void)removeNotifications {
    if (!self.sellectedNotifications.count) return;

    [self.destinationDelegate notificationListViewController:self requestsClearingNotificationRequests:[self.sellectedNotifications copy]];
    if (IN_LS) {
        [ncViewController.destinationDelegate notificationListViewController:self requestsClearingNotificationRequests:[self.sellectedNotifications copy]];
    }
}

%new - (BOOL)shouldShowNotificationAtIndexPath: (NSIndexPath *)indexPath {
    // if (self.recentlyClearedNotifications[[NSString stringWithFormat:@"%ld-%ld", (long)indexPath.row, (long)indexPath.section]]) return NO;
    if ([self.selectedAppID isEqualToString:@"-showAll"]) return YES;
    NSString *identifier = [[self notificationRequestAtIndexPath:indexPath] sectionIdentifier];
    BOOL showAllWhenNotSelected = [prefs boolForKey:(IN_LS) ? @"showAllWhenNotSelected" : @"ncshowAllWhenNotSelected"];

    if (!self.selectedAppID) {
        if ([prefs boolForKey:@"privacyMode"]) {
            return NO;
        }
        return showAllWhenNotSelected;
    }
    return [self.selectedAppID isEqualToString:identifier];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

%end

//
// ___ NCNotificationPriorityListViewController ___________________________________
//

%hook NCNotificationPriorityListViewController

- (void)insertNotificationRequest: (NCNotificationRequest *)request forCoalescedNotification: (id)notification {
    if (![prefs boolForKey:@"enabled"]) {
        %orig; return;
    }

    // I dont think this is necessary, it dosn't seam to make a difference
    [self.collectionView performBatchUpdates:^{
        [UIView setAnimationsEnabled:NO];

        if ([self.selectedAppID isEqualToString:[request sectionIdentifier]]) {
            [self.collectionView.collectionViewLayout invalidateLayout];
        }
    } completion:^(BOOL finished) {
        [UIView setAnimationsEnabled:YES];
        %orig;
        [(NCNotificationListViewController *) self insertOrModifyNotification:request];
    }];
}

- (void)modifyNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification {
    %orig;
    [(NCNotificationListViewController *) self insertOrModifyNotification:request];
}

- (void)removeNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification {
    %orig;
    [(NCNotificationListViewController *) self removeNotification:request];
}

- (BOOL)shouldAddHintTextForNotificationViewController:(id)viewController {
    return ([prefs boolForKey:@"enabled"] && [prefs boolForKey:@"disableHintText"]) ? NO : %orig(viewController);
}

%end

//
// ___ NCNotificationSectionListViewController ____________________________________
//

%hook NCNotificationSectionListViewController

- (void)insertNotificationRequest: (NCNotificationRequest *)request forCoalescedNotification: (id)notification {
    %orig;
    [(NCNotificationListViewController *) self insertOrModifyNotification:request];
}

- (void)modifyNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification {
    %orig;
    [(NCNotificationListViewController *) self insertOrModifyNotification:request];
}

- (void)removeNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification {
    %orig;
    [(NCNotificationListViewController *) self removeNotification:request];
}

- (CGSize)collectionView:(UICollectionView *)collection layout:(UICollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)section {
    return ([prefs boolForKey:@"ncEnabled"]) ? CGSizeZero : %orig;
}

%end

//
// ___ SBDashBoardClippingLine ____________________________________________________
//

// Hide line that shows when scrolling up on lock screen
%hook SBDashBoardClippingLine

- (void)layoutSubviews {
    %orig;
    if ([prefs boolForKey:@"enabled"])
        self.hidden = YES;
}

%end

//
// ___ SBDashBoardMainPageView ____________________________________________________
//

// Hide "Press home to unlock" label on lock screen if PH is at the bottom
%hook SBDashBoardMainPageView

- (void)_layoutCallToActionLabel {
    %orig;
    self.callToActionLabel.hidden = ([prefs boolForKey:@"enabled"] && [prefs intForKey:@"iconLocation"] == 1);
}

%end

//
// ___ SBDashBoardPageControl _____________________________________________________
//

// Hide lock screen page indicators if PH is at the bottom
%hook SBDashBoardPageControl

- (void)layoutSubviews {
    %orig;
    self.hidden = ([prefs boolForKey:@"enabled"] && [prefs intForKey:@"iconLocation"] == 1);
}

%end

//
// ___ SBNotificationSeparatorView ________________________________________________
//

// Hide bottom seporator in NC
%hook SBNotificationSeparatorView

- (void)layoutSubviews {
    %orig;
    self.hidden = ([prefs boolForKey:@"ncEnabled"]);
}

%end

//
// ___ SBSearchEtceteraLayoutView _________________________________________________
//

%hook SBSearchEtceteraLayoutView

- (void)_layoutPageControl {
    %orig;
    self._pageControl.hidden = ([prefs boolForKey:@"ncEnabled"]);
}

- (void)setContentBottomInset:(double)inset {
    inset = [prefs boolForKey:@"ncEnabled"] ? 14 : inset;
    %orig(inset);
}

%end

%hook SBNotificationCenterViewController

-(void)_loadGrabberContentView {
    return;
}

%end

//
// ___ SBLockScreenViewControllerBase _____________________________________________
//

// For the deselect on lock feature on lock screen
%hook SBLockScreenViewControllerBase

- (void)setInScreenOffMode: (BOOL)locked {
    %orig;
    if (![prefs boolForKey:@"enabled"] || !lsIconCollection) return;
    if ([prefs boolForKey:@"collapseOnLock"]) {
        [lsIconCollection selectItemWithIdentifier:nil animated:NO];
    } else {
        [lsIconCollection updateVisibleCellsAnimated:NO];
    }
}

- (void)didCompleteTransitionOutOfLockScreen {
    %orig;
    if (![prefs boolForKey:@"enabled"] || !lsIconCollection) return;
    if ([prefs boolForKey:@"collapseOnLock"]) {
        [lsIconCollection selectItemWithIdentifier:nil animated:NO];
    } else {
        [lsIconCollection updateVisibleCellsAnimated:NO];
    }
}

%end

//
// ___ SBNotificationCenterController _____________________________________________
//

// For the deselect on close feature in notification center
%hook SBNotificationCenterController

- (void)transitionDidBegin: (id)animated {
    %orig;
    if ([prefs boolForKey:@"ncEnabled"] && ncIconCollection) {
        [ncIconCollection updateVisibleCellsAnimated:NO];
    }

}

- (void)transitionDidFinish:(id)animated {
    %orig;
    if (![prefs boolForKey:@"ncEnabled"]) return;
    if ([prefs boolForKey:@"ncCollapseOnLock"] && ncIconCollection) {
        [ncIconCollection selectItemWithIdentifier:nil animated:NO];
    }
}

%end

//
// ___ SBDashBoardNotificationListViewController __________________________________
//

%hook SBDashBoardNotificationListViewController

- (UIEdgeInsets)_listViewContentInset {
    UIEdgeInsets insets = %orig;
    if (![prefs boolForKey:@"enabled"]) return insets;
    return UIEdgeInsetsMake(0, insets.left, insets.bottom, insets.right);
}

- (CGRect)_suggestedListViewFrame {
    CGRect suggestedFrame = %orig;

    if (![prefs boolForKey:@"enabled"] || ![prefs boolForKey:@"verticalAdjustmentEnabled"]) return suggestedFrame;

    if ([CSCProvider tweakWithDylibNameInstalledAndEnabled:@"motuumLS" plistName:@"com.creaturecoding.motuumls" enabledKey:@"kMLSEnabled"]) return suggestedFrame;

    CGFloat prefsOrigin = [prefs floatForKey:@"verticalAdjustmentTop"];
    CGFloat prefsHeight = [prefs floatForKey:@"verticalAdjustmentBottom"];

    return CGRectMake(
        CGRectGetMinX(suggestedFrame),
        CGRectGetMinY(suggestedFrame) + prefsOrigin,
        CGRectGetWidth(suggestedFrame),
        CGRectGetHeight(suggestedFrame) + prefsHeight
        );
}

%end

%hook NCNotificationOptions

- (BOOL)addToLockScreenWhenUnlocked {
    return [prefs boolForKey:@"alwaysSendToLockscreen"] ? : %orig;
}

- (BOOL)dismissAutomatically {
    return [prefs boolForKey:@"disableAutomaticDismiss"] ? : %orig;
}

- (NSUInteger)_lockScreenPersistence {
    return 1;
}

%end

