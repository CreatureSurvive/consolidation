#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <AppList/AppList.h>
#import "substrate.h"
#import "Headers.h"
#import "PHPullToClearView.h"
#import "CSCProvider.h"
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
UIView *calendarView = nil;
Class calendarClass;

CGSize appViewSize(BOOL lockscreen) {
    if ((lockscreen && ![prefs boolForKey:@"enabled"]) || (!lockscreen && ![prefs boolForKey:@"ncEnabled"]))
        return CGSizeZero;

    CGFloat width = 0;
    NSInteger iconSize = (lockscreen ? [prefs intForKey:@"iconSize"] : [prefs intForKey:@"ncIconSize"]);

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

    BOOL numberStyleBelow = (lockscreen ? [prefs intForKey:@"numberStyle"] == 1 : [prefs intForKey:@"ncNumberStyle"] == 1);
    CGFloat height = numberStyleBelow ? width * 1.6 : width;
    return CGSizeMake(width, height);
}

//
// ___ NCNotificationListCell _____________________________________________________
//

%hook NCNotificationListCell
%property(nonatomic, assign) BOOL scrolledOnce;

- (id)initWithFrame:(CGRect)frame {
    if (self == %orig(frame)) {
        [self performSelector:@selector(setupTapGesture) withObject:nil afterDelay:0.1];
    }
    return self;
}

%new - (void)setupTapGesture {
    if ([self.contentViewController isShortLook]) {
        if ([prefs boolForKey:@"tapToOpen"] && [prefs boolForKey:@"enabled"]) {
            UIView *lookView = [self.contentViewController.view performSelector:@selector(contentView)];
            UITapGestureRecognizer *tapToOpenRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
            [tapToOpenRecognizer setDelegate:self];
            [tapToOpenRecognizer setNumberOfTapsRequired:1];
            [tapToOpenRecognizer setNumberOfTouchesRequired:1];
            [lookView addGestureRecognizer:tapToOpenRecognizer];
        }
    }
}

%new - (void)handleTapFrom: (UITapGestureRecognizer *)recognizer {
    if (![self.contentViewController _presentedLongLookViewController]) {
        self.scrolledOnce = YES;
        [self.contentViewController _executeDefaultAction:YES];
    }
}

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
%property(nonatomic, retain) CSCCollectionViewController *iconCollection;
// %property(nonatomic, retain) NSMutableDictionary *recentlyClearedNotifications;

// //potential fix for unlock prompt
- (void)notificationListCell:(NCNotificationListCell *)cell requestsPerformAction:(id)arg2 forNotificationRequest:(id)arg3 completion:(id)arg4  {
    if (IN_LS && ENABLED && !cell.scrolledOnce) return;
    %orig;
}

- (CGSize)collectionView:(UICollectionView *)collection layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGSize itemSize = %orig;
    if (!ENABLED) return itemSize;
    return ([[(NCNotificationListCollectionViewFlowLayout *) layout removedIndexPaths] containsObject:indexPath] || [self shouldShowNotificationAtIndexPath:indexPath]) ?
           CGSizeMake(itemSize.width, itemSize.height + 8) : CGSizeMake(0.1, 0.1);
}

- (void)viewDidLoad {
    %orig;
    if (!ENABLED) return;
    // self.recentlyClearedNotifications = [NSMutableDictionary new];

    if (IN_LS) {
        lsViewController = (NCNotificationPriorityListViewController *)self;
    } else {
        ncViewController = (NCNotificationSectionListViewController *)self;
    }
    if (IN_LS && !lsIconCollection) {
        calendarClass = NSClassFromString(@"CFLCollectionFooterView");
        lsIconCollection = [CSCCollectionViewController new];
        [lsIconCollection.view setTranslatesAutoresizingMaskIntoConstraints:NO];
        [lsIconCollection setCellSize:appViewSize(YES)];
        [lsIconCollection setCollectionStyle:0];
        [lsIconCollection setShowAllSection:[prefs boolForKey:@"lsShowAllSection"]];
        [lsIconCollection setShowCalendarSection:calendarClass != nil];
        [self setIconCollection:lsIconCollection];
        [self addChildViewController:lsIconCollection];
        [self.view addSubview:lsIconCollection.view];
    } else if (!IN_LS && !ncIconCollection) {
        ncIconCollection = [CSCCollectionViewController new];
        [ncIconCollection.view setTranslatesAutoresizingMaskIntoConstraints:NO];
        [ncIconCollection setCellSize:appViewSize(NO)];
        [ncIconCollection setCollectionStyle:1];
        [ncIconCollection setShowAllSection:[prefs boolForKey:@"ncShowAllSection"]];
        [self setIconCollection:ncIconCollection];
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
    if (!ENABLED) return;
    [self updateConsolidationConstraintsAndLayout:NO];
}

// pull to clear update
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig;
    if (!ENABLED || self.selectedAppID == nil) {
        ((IN_LS) ? lsPullToClearView : ncPullToClearView).hidden = YES;
    } else {
        ((IN_LS) ? lsPullToClearView : ncPullToClearView).hidden = NO;
        [((IN_LS) ? lsPullToClearView : ncPullToClearView) didScroll:scrollView];
    }
}

// pull to clear trigger
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    %orig;
    if (!ENABLED || self.selectedAppID == nil) return;
    [((IN_LS) ? lsPullToClearView : ncPullToClearView) didEndDragging:scrollView];
}

%new - (void)checkForCalendarView {

    if (calendarClass && !calendarView) {
        for (UIView *view in self.collectionView.subviews) {
            if ([view isKindOfClass:calendarClass]) {
                calendarView = view;
                [calendarView setHidden:![self.selectedAppID isEqualToString:@"-calendarForLockscreen"]];
            }
        }
    } else if (calendarView) {
        [calendarView setHidden:![self.selectedAppID isEqualToString:@"-calendarForLockscreen"]];
    }

}

%new - (void)updateConsolidationConstraintsAndLayout: (BOOL)layout {
    self.collectionView.clipsToBounds = YES;
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;

    BOOL lockscreen = IN_LS;

    [self.iconCollection setCellSize:appViewSize(lockscreen)];

    // Layout container view
    BOOL onTop = ![prefs boolForKey:lockscreen ? @"iconLocation" : @"ncIconLocation"];
    CGFloat height = appViewSize(lockscreen).height + (self.iconCollection.collectionStyle ? 2 : 6);
    CGFloat top = onTop ? height : 0, bottom = !onTop ? -(height + 8) : 0;

    NSLayoutConstraint *edgeConstraint = onTop ? [NSLayoutConstraint constraintWithItem:self.iconCollection.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0] :
                                         [NSLayoutConstraint constraintWithItem:self.iconCollection.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-4.0];
    [self.view addConstraints:@[
         [NSLayoutConstraint constraintWithItem:self.collectionView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:self.collectionView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:self.collectionView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1 constant:bottom],
         [NSLayoutConstraint constraintWithItem:self.collectionView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:top],

         [NSLayoutConstraint constraintWithItem:self.iconCollection.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:self.iconCollection.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
         [NSLayoutConstraint constraintWithItem:self.iconCollection.view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:height],
         edgeConstraint
     ]];

    // Layout pull to clear view
    BOOL pullToClearEnabled = lockscreen ? [prefs boolForKey:@"enablePullToClear"] : [prefs boolForKey:@"ncEnablePullToClear"];
    CGRect currentFrame = (lockscreen ? lsPullToClearView : ncPullToClearView).frame;
    (lockscreen ? lsPullToClearView : ncPullToClearView).frame = CGRectMake(0, -(pullToClearSize + 8), self.collectionView.bounds.size.width, pullToClearSize);
    (lockscreen ? lsPullToClearView : ncPullToClearView).bounds = CGRectMake(CGRectGetMidX(currentFrame) - (pullToClearSize / 2), CGRectGetMidY(currentFrame) - (pullToClearSize / 2), pullToClearSize, pullToClearSize);
    (lockscreen ? lsPullToClearView : ncPullToClearView).hidden = !(pullToClearEnabled && ENABLED);

    if (layout) {
        [self.view layoutIfNeeded];
        [self.collectionView setNeedsLayout];
        [self.collectionView layoutIfNeeded];
        [self.iconCollection.view setNeedsLayout];
        [self.iconCollection.view layoutIfNeeded];
    }
}

// update for new notifications
%new - (void)insertOrModifyNotification: (NCNotificationRequest *)request {
    if (!ENABLED) return;

    [self.iconCollection updateContent];

    if (![prefs boolForKey:@"privacyMode"]) {
        if (![self.selectedAppID isEqualToString:[request sectionIdentifier]])
            [lsIconCollection selectItemWithIdentifier:[request sectionIdentifier] animated:YES];
    }
    [self.collectionView.collectionViewLayout invalidateLayout];
    [self performSelector:@selector(checkForCalendarView)];
}

%new - (void)removeNotification: (NCNotificationRequest *)request {
    if (!ENABLED) return;

    [self.iconCollection updateContent];
}

%new - (void)setupBlocks {

    self.iconCollection.allNotifications = ^NSArray *(){
        NSMutableArray *notifications = [NSMutableArray new];
        for (NSInteger section = 0; section < [self numberOfSectionsInCollectionView:self.collectionView]; section++) {
            for (NSInteger item = 0; item < [self collectionView:self.collectionView numberOfItemsInSection:section]; item++) {
                [notifications addObject:[self notificationRequestAtIndexPath:[NSIndexPath indexPathForRow:item inSection:section]]];
            }
        }
        return notifications;
    };

    self.iconCollection.setCurrentIdentifier = ^void (NSString *identifier) {
        self.selectedAppID = identifier;

        [self performSelector:@selector(checkForCalendarView)];

        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView setContentOffset:CGPointZero animated:NO];

        // Hide pull to clear view if no app is selected
        (IN_LS ? lsPullToClearView : ncPullToClearView).hidden = identifier == nil;

        NSDictionary *userInfo = @{
            @"isShowingNotifications": @(identifier != nil),
            @"isShowingNotificationsLS": @(lsViewController.selectedAppID != nil),
            @"isShowingNotificationsNC": @(ncViewController.selectedAppID != nil)
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
        [self.iconCollection selectItemWithIdentifier:nil animated:NO];
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
    NSString *identifier;
    @try {
        NCNotificationRequest *request = [self notificationRequestAtIndexPath:indexPath];
        identifier = request ? [request sectionIdentifier] : @"";
    }@catch (NSException *exception) {
        CSLog(@"CSC Error loading request index. ERROR: %@", exception);
    }
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
    %orig;
    if (![prefs boolForKey:@"enabled"]) return;
    [(NCNotificationListViewController *) self insertOrModifyNotification:request];

    // if ([self.selectedAppID isEqualToString:[request sectionIdentifier]]) {
    //     [self.collectionView.collectionViewLayout invalidateLayout];
    // }
}

- (void)modifyNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification {
    %orig;
    [(NCNotificationListViewController *) self insertOrModifyNotification:request];
}

- (void)removeNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification {
    %orig;
    [(NCNotificationListViewController *) self removeNotification:request];
}

- (CGSize)collectionView:(UICollectionView *)collection layout:(UICollectionViewLayout *)layout referenceSizeForFooterInSection:(NSInteger)section {
    CGSize itemSize = %orig;
    if (![prefs boolForKey:@"enabled"]) return itemSize;
    return calendarView.hidden ? CGSizeMake(0.1, 0.1) : itemSize;
}

- (BOOL)shouldAddHintTextForNotificationViewController:(id)viewController {
    return ([prefs boolForKey:@"enabled"] && [prefs boolForKey:@"disableHintText"]) ? NO : %orig(viewController);
}

- (void)clearAllNonPersistent {
    if ([prefs boolForKey:@"disableAutomaticDismiss"]) return;
    %orig;
}

- (void)clearAll {
    if ([prefs boolForKey:@"disableAutomaticDismiss"]) return;
    %orig;
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
    self.hidden = ([prefs boolForKey:@"ncEnabled"] && [prefs boolForKey:@"ncHideChevronAndLine"]);
}

%end

//
// ___ SBSearchEtceteraLayoutView _________________________________________________
//

%hook SBSearchEtceteraLayoutView

- (void)_layoutPageControl {
    %orig;
    self._pageControl.hidden = ([prefs boolForKey:@"ncEnabled"] && [prefs boolForKey:@"ncHideChevronAndLine"]);
}

- (void)setContentBottomInset:(double)inset {
    inset = ([prefs boolForKey:@"ncEnabled"] && [prefs boolForKey:@"ncHideChevronAndLine"]) ? 14 : inset;
    %orig(inset);
}

%end

%hook SBNotificationCenterViewController

-(void)_loadGrabberContentView {
    if ([prefs boolForKey:@"ncEnabled"] && [prefs boolForKey:@"ncHideChevronAndLine"]) return;
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

- (void)viewDidLoad {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updatePresentation) name:@"kCSCPrefsChanged" object:nil];
}

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

- (void)_updatePresentation {
    %orig;

    if (![prefs boolForKey:@"enabled"] || ![prefs boolForKey:@"verticalAdjustmentEnabled"]) return;

    SBFTouchPassThroughView *notificationView = [self valueForKey:@"_clippingView"];
    [notificationView setFrame:[self _suggestedListViewFrame]];
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

%ctor {
    dlopen("/Library/MobileSubstrate/DynamicLibraries/CalendarForLockscreen2.dylib", RTLD_LAZY);
}

