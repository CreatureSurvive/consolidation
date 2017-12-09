#import "CSCCollectionViewCell.h"

@interface CSCCollectionViewController : UIViewController<UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, assign) CSCCollectionStyle collectionStyle;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSOrderedSet *indexedRequests;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (nonatomic, assign) CGSize cellSize;
@property (nonatomic, assign) BOOL showAllSection;

@property (nonatomic, copy) NSArray * (^allNotifications)();
@property (nonatomic, copy) void (^setCurrentIdentifier)(NSString *identifier);

- (void)updateContent;
- (void)selectItemWithIdentifier:(NSString *)identifier animated:(BOOL)animated;
- (void)updateContentAndSelectItemWithIdentifier:(NSString *)identifier animated:(BOOL)animated;
- (void)updateVisibleCellsAnimated:(BOOL)animated;
@end