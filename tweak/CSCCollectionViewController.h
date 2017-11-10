#import "CSCCollectionViewCell.h"

@interface CSCCollectionViewController : UIViewController<UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSOrderedSet *indexedRequests;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (nonatomic, assign) CGSize cellSize;

@property (nonatomic, copy) NSArray * (^allNotifications)();
@property (nonatomic, copy) UIImage * (^iconForIdentifier)(NSString *);
@property (nonatomic, copy) void (^setCurrentIdentifier)(NSString *identifier);

- (void)updateContent;
@end