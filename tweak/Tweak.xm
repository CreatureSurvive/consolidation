#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <AppList/AppList.h>
#import "substrate.h"
#import "Headers.h"
#import "PHContainerView.h"
#import "PHPullToClearView.h"
#import "CSCProvider.h"
#import "CSCCollectionViewController.h"

#define prefs [CSCProvider sharedProvider]
#define IN_LS [self isKindOfClass:%c(NCNotificationPriorityListViewController)]
#define ENABLED ((IN_LS && [prefs boolForKey:@"enabled"]) || (!IN_LS && [prefs boolForKey:@"ncEnabled"]))

PHContainerView *lsPhContainerView = nil;
PHContainerView *ncPhContainerView = nil;
PHPullToClearView *lsPullToClearView = nil;
PHPullToClearView *ncPullToClearView = nil;
NCNotificationPriorityListViewController *lsViewController = nil;
NCNotificationSectionListViewController *ncViewController = nil;
CSCCollectionViewController *lsIconCollection = nil;
CSCCollectionViewController *ncIconCollection = nil;
NSMutableDictionary *iconCache = nil;

CGSize appViewSize(BOOL lockscreen) {
    if ((lockscreen && ![prefs boolForKey:@"enabled"]) || (!lockscreen && ![prefs boolForKey:@"ncEnabled"]))
        return CGSizeZero;

    CGFloat width = 0;
    NSInteger iconSize = (lockscreen) ? [prefs intForKey:@"iconSize"] : [prefs intForKey:@"ncIconSize"];

    switch (iconSize) {
        default:
        case 0:
            width = 40;
            break;
        case 1:
            width = 53;
            break;
        case 2:
            width = 63;
            break;
        case 3:
            width = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 106 : 84;
            break;
    }

    BOOL numberStyleBelow = (lockscreen) ? ([prefs intForKey:@"numberStyle"] == 1) : ([prefs intForKey:@"ncNumberStyle"] == 1);
    CGFloat height = (numberStyleBelow) ? width * 1.45 : width;
    return CGSizeMake(width, height);
}

UIImage *iconForIdentifier(NSString *identifier) {
    if ([identifier isEqualToString:@"com.apple.DuetHeuristic-BM"]) {
        return [UIImage imageNamed:@"BatteryIcon" inBundle:[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/DuetHeuristics.framework"] compatibleWithTraitCollection:nil];
    }

    UIImage *icon = [[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeLarge forDisplayIdentifier:identifier];

    if (!icon) {
        // better than nothing 20x20 icon from the request
        icon = iconCache[identifier];
    }

    return icon;

    // Apple 2FA identifier: com.apple.springboard.SBUserNotificationAlert
    // Low power mode identifier (maybe): com.apple.DuetHeuristic-BM
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
// ─── NCNotificationListViewController ───────────────────────────────────────────
//

%hook NCNotificationListViewController
%property(nonatomic, retain) NSString *selectedAppID;
%property(nonatomic, retain) NSMutableArray *sellectedNotifications;

// //potential fix for unlock prompt
- (void)notificationListCell:(NCNotificationListCell *)cell requestsPerformAction:(id)arg2 forNotificationRequest:(id)arg3 completion:(id)arg4  {
    if (ENABLED && !cell.scrolledOnce) return;
    %orig;
}

// sets the size of hidden notifications to 1x1 inorder to remove spaces for hidden notifications
// setting this to CGSizeZero will result in the collectionView using the layout size which also does not accept 0 size cell
// it seams that even wen seting 1x1 as the size in the layout, it is still ignored, propably because NCNotificationListViewController
// implements this method on its own, so we are forced to do the same
- (CGSize)collectionView:(UICollectionView *)collection layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (!ENABLED) return %orig;
    if (![self shouldShowNotificationAtIndexPath:indexPath]) {
        return CGSizeMake(0.1, 0.1);
    } else {
        return %orig;
    }
}

- (void)viewDidLoad {
    %orig;

    if (IN_LS) {
        lsViewController = (NCNotificationPriorityListViewController *)self;
    } else {
        ncViewController = (NCNotificationSectionListViewController *)self;
    }
    if (IN_LS && !lsIconCollection) {
        lsIconCollection = [CSCCollectionViewController new];
        // lsIconCollection.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, 40);
        lsIconCollection.view.translatesAutoresizingMaskIntoConstraints = NO;
        lsIconCollection.cellSize = appViewSize(YES);
        [self addChildViewController:lsIconCollection];
        [self.view addSubview:lsIconCollection.view];
    } else if (!ncIconCollection) {
        ncIconCollection = [CSCCollectionViewController new];
        // ncIconCollection.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, 40);
        ncIconCollection.view.translatesAutoresizingMaskIntoConstraints = NO;
        ncIconCollection.cellSize = appViewSize(NO);
        [self addChildViewController:ncIconCollection];
        [self.view addSubview:ncIconCollection.view];
    }

    // Create the PHContainerView
    if (IN_LS && !lsPhContainerView) {
        lsPhContainerView = [[PHContainerView alloc] init:YES];
        lsPhContainerView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:lsPhContainerView];
    } else if (!ncPhContainerView) {
        ncPhContainerView = [[PHContainerView alloc] init:YES];
        ncPhContainerView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:ncPhContainerView];
    }

    // Create the pull to clear view
    if (!(IN_LS ? lsPullToClearView : ncPullToClearView)) {
        (IN_LS ? lsPullToClearView : ncPullToClearView) = [[PHPullToClearView alloc] initWithStyle:!(IN_LS)];
        [self.collectionView addSubview:((IN_LS) ? lsPullToClearView : ncPullToClearView)];
    }

    //sets the block methods for the pulltoclear and container views
    [self setupBlocks];
    (IN_LS ? lsPullToClearView : ncPullToClearView).hidden = YES;
    (IN_LS ? lsPhContainerView : lsPhContainerView).hidden = YES;
}

- (void)viewWillLayoutSubviews {
    %orig;

    if (!ENABLED) {
        self.collectionView.frame = self.view.bounds;
        self.collectionView.translatesAutoresizingMaskIntoConstraints = YES;
        (IN_LS ? lsPhContainerView : ncPhContainerView).hidden = YES;
        return;
    }

    (IN_LS ? lsPhContainerView : ncPhContainerView).hidden = YES;
    self.collectionView.clipsToBounds = YES;
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;

    // Layout container view
    BOOL onTop = ![prefs boolForKey:@"iconLocation"];
    CGFloat height = appViewSize((IN_LS)).height;
    CGFloat top = onTop ? height : 0, bottom = !onTop ? -(height + 8) : 0;
    NSLayoutConstraint *edgeConstraint = onTop ? [NSLayoutConstraint constraintWithItem:((IN_LS) ? lsPhContainerView : ncPhContainerView) attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0] :
                                         [NSLayoutConstraint constraintWithItem:((IN_LS) ? lsPhContainerView : ncPhContainerView) attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-4.0];

    NSLayoutConstraint *edgeConstraint1 = onTop ? [NSLayoutConstraint constraintWithItem:(IN_LS ? lsIconCollection.view : ncIconCollection.view) attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0] :
                                          [NSLayoutConstraint constraintWithItem:(IN_LS ? lsIconCollection.view : ncIconCollection.view) attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-4.0];
    [self.view addConstraints:@[
         [NSLayoutConstraint constraintWithItem:self.collectionView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:self.collectionView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:self.collectionView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1 constant:bottom],
         [NSLayoutConstraint constraintWithItem:self.collectionView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:top],

         [NSLayoutConstraint constraintWithItem:((IN_LS) ? lsPhContainerView : ncPhContainerView) attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:((IN_LS) ? lsPhContainerView : ncPhContainerView) attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:((IN_LS) ? lsPhContainerView : ncPhContainerView) attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:height],
         edgeConstraint,

         [NSLayoutConstraint constraintWithItem:(IN_LS ? lsIconCollection.view : ncIconCollection.view) attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:(IN_LS ? lsIconCollection.view : ncIconCollection.view) attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:(IN_LS ? lsIconCollection.view : ncIconCollection.view) attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:height],
         edgeConstraint1
     ]];

    // Layout pull to clear view
    BOOL pullToClearEnabled = (IN_LS) ? [prefs boolForKey:@"enablePullToClear"] : [prefs boolForKey:@"ncEnablePullToClear"];
    CGRect currentFrame = ((IN_LS) ? lsPullToClearView : ncPullToClearView).frame;
    (IN_LS ? lsPullToClearView : ncPullToClearView).frame = CGRectMake(0, -(pullToClearSize + 8), self.collectionView.bounds.size.width, pullToClearSize);
    (IN_LS ? lsPullToClearView : ncPullToClearView).bounds = CGRectMake(CGRectGetMidX(currentFrame) - (pullToClearSize / 2), CGRectGetMidY(currentFrame) - (pullToClearSize / 2), pullToClearSize, pullToClearSize);
    (IN_LS ? lsPullToClearView : ncPullToClearView).hidden = !(pullToClearEnabled && ENABLED);
}

// pull to clear update
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig;
    if (!ENABLED) return;
    [((IN_LS) ? lsPullToClearView : ncPullToClearView) didScroll:scrollView];
}

// pull to clear trigger
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    %orig;
    if (!ENABLED) return;
    [((IN_LS) ? lsPullToClearView : ncPullToClearView) didEndDragging:scrollView];
}

// update for new notifications
%new - (void)insertOrModifyNotification: (NCNotificationRequest *)request {
    if (!ENABLED) return;

    if (!iconCache) iconCache = [NSMutableDictionary new];
    if (!iconCache[[request sectionIdentifier]]) {
        iconCache[[request sectionIdentifier]] = [[request content] icon];
    }


    IN_LS ? [lsPhContainerView updateView] : [ncPhContainerView updateView];
    IN_LS ? [lsIconCollection updateContent] : [ncIconCollection updateContent];

    if (IN_LS && [prefs boolForKey:@"privacyMode"]) {
        [lsPhContainerView selectAppID:nil newNotification:NO];
    } else {
        [((IN_LS) ? lsPhContainerView : ncPhContainerView) selectAppID:[request sectionIdentifier] newNotification:YES];
    }
}

%new - (void)removeNotification: (NCNotificationRequest *)request {
    if (!ENABLED) return;

    IN_LS ? [lsPhContainerView updateView] : [ncPhContainerView updateView];
    IN_LS ? [lsIconCollection updateContent] : [ncIconCollection updateContent];
}

%new - (void)setupBlocks {
    ((IN_LS) ? lsPhContainerView : ncPhContainerView).setAppID = ^void (NSString *identifier) {
        self.selectedAppID = identifier;
    };

    (IN_LS ? lsIconCollection : ncIconCollection).iconForIdentifier = ^UIImage *(NSString *identifier) {
        return iconForIdentifier(identifier);
    };

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
    };

    // Set up notification fetching block
    ((IN_LS) ? lsPhContainerView : ncPhContainerView).getCurrentNotifications = ^NSDictionary *() {
        NSMutableDictionary *notificationsDict = [NSMutableDictionary new];

        // Loop through all sections and rows
        for (NSInteger section = 0; section < [self numberOfSectionsInCollectionView:self.collectionView]; section++) {
            for (NSInteger item = 0; item < [self collectionView:self.collectionView numberOfItemsInSection:section]; item++) {
                NSString *identifier = [[self notificationRequestAtIndexPath:[NSIndexPath indexPathForRow:item inSection:section]] sectionIdentifier];
                unsigned int numNotifications = 1;
                if (notificationsDict[identifier]) {
                    numNotifications = [notificationsDict[identifier] unsignedIntegerValue] + 1;
                }
                [notificationsDict setObject:[NSNumber numberWithUnsignedInteger:numNotifications] forKey:identifier];
            }
        }
        return notificationsDict;
    };

    // Set up table view update block
    ((IN_LS) ? lsPhContainerView : ncPhContainerView).updateNotificationView = ^void () {
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView setContentOffset:CGPointZero animated:NO];

        // Hide pull to clear view if no app is selected
        ((IN_LS) ? lsPullToClearView : ncPullToClearView).hidden = !self.selectedAppID;
    };


    ((IN_LS) ? lsPullToClearView : ncPullToClearView).clearBlock = ^void () {
        self.sellectedNotifications = [NSMutableArray new];
        for (NSInteger section = 0; section < [self numberOfSectionsInCollectionView:self.collectionView]; section++) {
            for (NSInteger item = 0; item < [self collectionView:self.collectionView numberOfItemsInSection:section]; item++) {
                NCNotificationRequest *request = [self notificationRequestAtIndexPath:[NSIndexPath indexPathForRow:item inSection:section]];
                if (![[request sectionIdentifier] isEqualToString:self.selectedAppID]) continue;
                [self.sellectedNotifications addObject:request];
            }
        }
        // if ([self isKindOfClass:NSClassFromString(@"NCNotificationPriorityListViewController")]) {

        //     NCNotificationPriorityListViewController *priorityList = (NCNotificationPriorityListViewController *)self;

        //     if (![priorityList notificationRequestList] ||
        //         ![priorityList notificationRequestList].requests ||
        //         ![priorityList notificationRequestList].requests.count) return;

        //     for (NCNotificationRequest *request in [priorityList notificationRequestList].requests) {
        //         if ([[request sectionIdentifier] isEqualToString:((IN_LS) ? lsPhContainerView : ncPhContainerView).selectedAppID]) {
        //             [self.sellectedNotifications addObject:request];
        //         }
        //     }

        // } else if ([self isKindOfClass:NSClassFromString(@"NCNotificationSectionListViewController")]) {
        //     NCNotificationSectionListViewController *sectionsList = (NCNotificationSectionListViewController *)self;
        //     NCNotificationChronologicalList *chronologicalList = (NCNotificationChronologicalList *)[sectionsList sectionList];

        //     if (![chronologicalList sections] ||
        //         ![chronologicalList sections].count ||
        //         ![[chronologicalList sections][0] notificationRequests] ||
        //         ![[chronologicalList sections][0] notificationRequests].count) return;

        //     for (NCNotificationRequest *request in [[chronologicalList sections][0] notificationRequests]) {
        //         if ([[request sectionIdentifier] isEqualToString:((IN_LS) ? lsPhContainerView : ncPhContainerView).selectedAppID]) {
        //             [self.sellectedNotifications addObject:request];
        //         }
        //     }
        // }

        [self removeNotifications];
    };
}

%new - (void)removeNotifications {
    if (!self.sellectedNotifications.count) return;

    // clear Notifications
    [self.destinationDelegate notificationListViewController:self requestsClearingNotificationRequests:[self.sellectedNotifications copy]];
    if (IN_LS) {
        [ncViewController.destinationDelegate notificationListViewController:self requestsClearingNotificationRequests:[self.sellectedNotifications copy]];
    }
    // self.isClearing = NO;
    // NCNotificationRequest *request = (NCNotificationRequest *)self.sellectedNotifications[0];
    // [self.sellectedNotifications removeObject:request];
    // // self.isClearing = !(self.sellectedNotifications.count >= 1);
    // [request.clearAction.actionRunner executeAction:request.clearAction fromOrigin:nil withParameters:nil completion:^{
    //     if (self.sellectedNotifications.count) {
    //         [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(removeNotifications) userInfo:nil repeats:NO];
    //     }
    // }];
}

%new - (BOOL)shouldShowNotificationAtIndexPath: (NSIndexPath *)indexPath {
    NSString *identifier = [[self notificationRequestAtIndexPath:indexPath] sectionIdentifier];
    BOOL showAllWhenNotSelected = (IN_LS && [prefs boolForKey:@"showAllWhenNotSelected"]) || (!IN_LS && [prefs boolForKey:@"ncShowAllWhenNotSelected"]);

    if (!self.selectedAppID) {
        if ([prefs boolForKey:@"privacyMode"]) {
            return NO;
        }
        return showAllWhenNotSelected;
    }
    return [self.selectedAppID isEqualToString:identifier];
}

%end

//
// ___ NCNotificationPriorityListViewController ___________________________________
//

%hook NCNotificationPriorityListViewController

- (void)insertNotificationRequest: (NCNotificationRequest *)request forCoalescedNotification: (id)notification {
    if (![prefs boolForKey:@"enabled"]) {
        %orig;
        return;
    }
    self.selectedAppID = [request sectionIdentifier];

    // I dont think this is necessary, it dowsnt seam to make a difference
    [self.collectionView performBatchUpdates:^{
        [UIView setAnimationsEnabled:NO];
        [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
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
    if ([prefs boolForKey:@"enabled"] && [prefs boolForKey:@"disableHintText"]) {
        return NO;
    } else {
        return %orig(viewController);
    }
}

%end

//
// ___ NCNotificationSectionListViewController ____________________________________
//

%hook NCNotificationSectionListViewController

- (void)insertNotificationRequest: (NCNotificationRequest *)request forCoalescedNotification: (id)notification {
    if (![prefs boolForKey:@"ncEnabled"]) {
        %orig;
        return;
    }
    ncPhContainerView.selectedAppID = [request sectionIdentifier];
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
// ─── SBDashBoardClippingLine ─────��─────���──────────────────���────────���─������──────����───
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
// ��── SBDashBoardMainPageView ────────────────────────────────────────────────────
//

// Hide "Press home to unlock" label on lock screen if PH is at the bottom
%hook SBDashBoardMainPageView

- (void)_layoutCallToActionLabel {
    %orig;
    self.callToActionLabel.hidden = ([prefs boolForKey:@"enabled"] && [prefs intForKey:@"iconLocation"] == 1);
}

%end

//
// ─── SBDashBoardPageControl ───────��������──���───────────────────���─────────────────────
//

// Hide lock screen page indicators if PH is at the bottom
%hook SBDashBoardPageControl

- (void)layoutSubviews {
    %orig;
    self.hidden = ([prefs boolForKey:@"enabled"] && [prefs intForKey:@"iconLocation"] == 1);
}

%end

//
// ─── SBLockScreenViewControllerBase ─────────────────────────────────────────────
//

// For the deselect on lock feature on lock screen
%hook SBLockScreenViewControllerBase

- (void)setInScreenOffMode: (BOOL)locked {
    %orig;
    if (locked && [prefs boolForKey:@"enabled"] && [prefs boolForKey:@"collapseOnLock"] && lsPhContainerView) {
        [lsPhContainerView selectAppID:lsPhContainerView.selectedAppID newNotification:NO];
    }
}

%end

//
// ─── SBNotificationCenterController ─────────────────────────────────────────────
//

// For the deselect on close feature in notification center
%hook SBNotificationCenterController

- (void)transitionDidBegin: (id)animated {
    %orig;
    if (![prefs boolForKey:@"ncEnabled"]) return;
    [ncPhContainerView updateView];
    [ncPhContainerView selectAppID:ncPhContainerView.selectedAppID newNotification:NO];
    ncPhContainerView.updateNotificationView();
}

- (void)transitionDidFinish:(id)animated {
    %orig;
    if (![prefs boolForKey:@"ncEnabled"]) return;
    if (![self isVisible] && [prefs boolForKey:@"ncCollapseOnLock"] && ncPhContainerView) {
        [ncPhContainerView selectAppID:ncPhContainerView.selectedAppID newNotification:NO];
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

// - (NSUInteger)_lockScreenPersistence {
//     return 0;
// }

%end
