#import "CSCCollectionViewController.h"

@interface SBSearchEtceteraLayoutContentView : UIView
@end

@interface SBSearchEtceteraLayoutView : UIView
@property (getter = _pageControl, nonatomic, retain, readonly) UIPageControl *pageControl;
@end

@interface SBNotificationSeparatorView : UIView
@end

@interface SBSearchEtceteraNotificationsLayoutContentView : SBSearchEtceteraLayoutContentView
@end

@interface NCNotificationListContainerViewController : UIViewController
@end

@interface SBNotificationCenterViewController : UIViewController
@end

@interface NCNotificationListCollectionViewFlowLayout : UICollectionViewFlowLayout
@property(nonatomic, retain) NSDictionary *layoutInformation;
@property (nonatomic, retain) NSMutableArray *removedIndexPaths;
- (BOOL)isLockscreenLayout;
- (BOOL)isConsolidationEnabledForLayout;
@end

@interface NCNotificationListClearButton : UIControl
@end

@interface SBDashBoardPageControl : UIPageControl
@end

@interface SBFTouchPassThroughView : UIView
@end

@interface SBDashBoardMainPageView : UIView
@property(retain, nonatomic) UILabel *callToActionLabel;
@end

@interface SBDashBoardClippingLine : UIView
@end

@protocol NCNotificationListViewControllerDestinationDelegate <NSObject>
@required
- (void)notificationListViewController:(id)controller requestsClearingNotificationRequests:(NSArray *)requests;
@end

@interface SBNotificationCenterController : NSObject
@property (getter = isVisible, nonatomic, readonly) BOOL visible;
@end

@protocol NCNotificationSectionList
@required
- (void)clearAllSections;
- (NSMutableSet *)allNotificationRequests;
@end

@protocol NCNotificationActionRunner <NSObject>
@required
- (void)executeAction:(id)arg1 fromOrigin:(id)arg2 withParameters:(id)arg3 completion:(id)arg4;
@end

@interface NCNotificationAction : NSObject
@property (nonatomic, readonly) id<NCNotificationActionRunner> actionRunner;
@end

@interface NCNotificationSound : NSObject
@end

@interface NCNotificationContent : NSObject
@property (nonatomic, readonly) UIImage *icon;
@end

@interface NCNotificationRequest : NSObject
@property (nonatomic, copy, readonly) NSString *sectionIdentifier;
@property (nonatomic, copy, readonly) NSSet *requestDestinations;
@property (nonatomic, readonly) NCNotificationSound *sound;
@property (nonatomic, readonly) NCNotificationAction *clearAction;
@property (nonatomic, readonly) NCNotificationAction *closeAction;
@property (nonatomic, readonly) NCNotificationAction *defaultAction;
@property (nonatomic, readonly) NCNotificationContent *content;
@end

@interface NCMutableNotificationRequest : NCNotificationRequest
@end

@interface NCTransitionManager : NSObject
- (BOOL)hasCommittedToPresentingLongLookViewController;
@end

@interface NCNotificationContentView : UIView
@end

@interface NCNotificationShortLookView : UIView //NCShortLookView
@end

@interface NCNotificationViewController : UIViewController
@property (nonatomic, retain) NCNotificationRequest *notificationRequest;
@property (getter = _transitionManager, nonatomic, retain) NCTransitionManager *transitionManager;
- (void)_executeDefaultAction:(BOOL)arg1;
- (void)_executeClearAction:(BOOL)arg1;
- (void)_executeCloseAction:(BOOL)arg1;
- (BOOL)isLookStyleLongLook;
- (BOOL)isShortLook;
- (id)_presentedLongLookViewController;
@end

@interface NCNotificationShortLookViewController : NCNotificationViewController
- (NCNotificationShortLookView *)_notificationShortLookViewIfLoaded;
@end

@interface NCNotificationListCell : UICollectionViewCell <UIGestureRecognizerDelegate>
@property(nonatomic, assign) BOOL scrolledOnce;
@property (assign, getter = isConfigured, nonatomic) BOOL configured;
@property (assign, getter = isExecutingDefaultAction, nonatomic) BOOL executingDefaultAction;
@property (nonatomic, retain) NCNotificationViewController *contentViewController;
@property (assign, nonatomic) BOOL supportsSwipeToDefaultAction;
@end

@interface NCNotificationListSection : NSObject
@property (nonatomic, retain) NSMutableArray *notificationRequests;
@end

@interface NCNotificationPriorityList : NSObject
@property (nonatomic, retain) NSMutableOrderedSet *requests;
- (NSInteger)count;
- (NSString *)_identifierForNotificationRequest:(NCNotificationRequest *)request;
@end

@interface NCNotificationChronologicalList : NSObject <NCNotificationSectionList>
@property (nonatomic, retain) NSMutableArray *sections;
- (NSMutableSet *)allNotificationRequests;
@end

@interface NCNotificationListViewController : UICollectionViewController <UICollectionViewDelegateFlowLayout>
//new
@property(nonatomic, retain) NSString *selectedAppID;
@property(nonatomic, retain) NSMutableArray *sellectedNotifications;
@property(nonatomic, retain) NSMutableDictionary *recentlyClearedNotifications;
@property(nonatomic, retain) CSCCollectionViewController *iconCollection;
@property (assign, nonatomic) id<NCNotificationListViewControllerDestinationDelegate> destinationDelegate;
@property (assign, nonatomic) NCNotificationListCell *cellWithRevealedActions;

- (long long)collectionView:(id)arg1 numberOfItemsInSection:(long long)arg2;
- (long long)numberOfSectionsInCollectionView:(id)arg1;
- (NSString *)notificationIdentifierAtIndex:(NSUInteger)index;
- (NSUInteger)numNotifications;
- (NCNotificationRequest *)notificationRequestAtIndexPath:(NSIndexPath *)path;
- (NSIndexPath *)indexPathForNotificationRequest:(NCNotificationRequest *)request;
- (BOOL)shouldShowNotificationAtIndexPath:(NSIndexPath *)indexPath;
- (void)removeNotification:(NCNotificationRequest *)request;
- (void)insertOrModifyNotification:(NCNotificationRequest *)request;
- (void)setNeedsReloadData:(BOOL)arg1;
- (bool)collectionView:(id)arg1 canMoveItemAtIndexPath:(id)arg2;
- (void)moveItemAtIndexPath:(NSIndexPath *)path toIndexPath:(NSIndexPath *)toPath;
- (void)removeNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification;
- (void)updateConsolidationConstraintsAndLayout:(BOOL)layout;
- (NSArray *)allIndexPaths;
- (void)removeNotifications;
- (void)setupBlocks;
@end

@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)identifier format:(int)format;
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)identifier format:(int)format scale:(float)scale;
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)identifier roleIdentifier:(id)id format:(int)format scale:(float)scale;
@end

@interface NCNotificationPriorityListViewController : NCNotificationListViewController
- (NSOrderedSet *)allNotificationRequests;
- (NCNotificationPriorityList *)notificationRequestList;
- (NCNotificationRequest *)notificationRequestAtIndexPath:(NSIndexPath *)path;
- (void)insertNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification;
- (void)modifyNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification;
- (void)removeNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification;
- (void)_reloadNotificationViewControllerForHintTextAtIndexPaths:(id)arg1;
- (void)_reloadNotificationViewControllerForHintTextAtIndexPath:(id)arg1;
- (void)hideRequestsForNotificationSectionIdentifier:(id)arg1 subSectionIdentifier:(id)arg2;
- (void)showRequestsForNotificationSectionIdentifier:(id)arg1 subSectionIdentifier:(id)arg2;
@end

@interface NCNotificationSectionListViewController : NCNotificationListViewController {
    id<NCNotificationSectionList> _sectionList;
}
- (void)sectionHeaderViewDidReceiveClearAllAction:(id)action;
- (id<NCNotificationSectionList>)sectionList;
@end

@interface NCNotificationListCollectionView : UICollectionView
- (NCNotificationPriorityListViewController *)dataSource;
@end

@interface SBDashBoardNotificationListViewController : UIViewController
- (NCNotificationListCollectionView *)notificationListScrollView;
- (NSUInteger)numNotifications;
- (NSString *)notificationIdentifierAtIndex:(NSUInteger)index;
- (CGRect)_suggestedListViewFrame;
@end

@interface SBApplication : NSObject
@end

@interface SBApplicationController : NSObject
+ (id)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)arg1;
@end

@interface NCMaterialView : UIView
@property (assign, nonatomic) double grayscaleValue;
+ (id)materialViewWithStyleOptions:(unsigned long long)arg1;

@end

@interface NSTimer (IOS10)

+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval
                                    repeats:(BOOL)repeats
                                      block:(void (^)(NSTimer *timer))block;

@end