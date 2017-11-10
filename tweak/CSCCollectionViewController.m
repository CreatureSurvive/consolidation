#import "CSCCollectionViewController.h"

@interface Request : NSObject
@property(retain, nonatomic) NSString *identifier;
@property(assign, nonatomic) NSInteger count;
@property(retain, nonatomic) UIImage *icon;
@end

@implementation Request

- (id)requestWithIdentifier:(NSString *)identifier count:(NSInteger)count icon:(UIImage *)icon {
    if (self == [super init]) {
        self.identifier = identifier;
        self.count = count;
        self.icon = icon;
    }
    return self;
}

@end

@implementation CSCCollectionViewController


#pragma mark - UIViewController

- (void)loadView {
    [super loadView];
    self.view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal];

    [layout setMinimumInteritemSpacing:8];
    [layout setMinimumLineSpacing:8];

    _collectionView = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:layout];
    [_collectionView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [_collectionView setAllowsMultipleSelection:YES];

    [_collectionView setDataSource:self];
    [_collectionView setDelegate:self];

    [_collectionView registerClass:[CSCCollectionViewCell class] forCellWithReuseIdentifier:@"notificationSectionCell"];
    [_collectionView setBackgroundColor:[UIColor clearColor]];

    [_collectionView setShowsHorizontalScrollIndicator:NO];
    [_collectionView setShowsVerticalScrollIndicator:NO];

    [self.view addSubview:_collectionView];
}

#pragma mark - UICollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _indexedRequests.count;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CSCCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"notificationSectionCell" forIndexPath:indexPath];

    Request *request = [self requestAtIndexPath:indexPath];
    [cell setCount:@(request.count).stringValue];
    [cell setIcon:request.icon];
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *indexPaths = collectionView.indexPathsForSelectedItems;
    _selectedIndexPath = indexPath;
    self.setCurrentIdentifier([self requestAtIndexPath:_selectedIndexPath].identifier);
    for (NSIndexPath *otherIndexPath in indexPaths) {
        if ([otherIndexPath isEqual:indexPath]) continue;
        [collectionView deselectItemAtIndexPath:otherIndexPath animated:NO];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    _selectedIndexPath = nil;
    self.setCurrentIdentifier(nil);
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return _cellSize;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    CGFloat padding = 8;
    CGFloat numberOfCells = [self collectionView:collectionView numberOfItemsInSection:section];
    CGFloat collectionWidth = collectionView.bounds.size.width;
    CGFloat contentWidth = (numberOfCells * collectionViewLayout.itemSize.width) + ((numberOfCells -1) * collectionViewLayout.minimumInteritemSpacing);

    if (contentWidth < collectionWidth) {
        padding = (collectionWidth - contentWidth) / 2;
    }
    return UIEdgeInsetsMake(0, padding, 0, padding);
}

#pragma mark - Misc

- (Request *)requestAtIndexPath:(NSIndexPath *)indexPath {
    return [_indexedRequests objectAtIndex:indexPath.row];
}

- (NSString *)countForCellAtIndexPath:(NSIndexPath *)indexPath {
    return @([self requestAtIndexPath:indexPath].count).stringValue;
}

- (UIImage *)iconForCellAtIndexPath:(NSIndexPath *)indexPath {
    return self.iconForIdentifier([self requestAtIndexPath:indexPath].identifier);
}

- (void)setIndexedRequests:(NSOrderedSet *)requests {
    _indexedRequests = requests;
    [_collectionView reloadData];
}

- (void)setCellSize:(CGSize)size {
    _cellSize = size;
    [(UICollectionViewFlowLayout *)[_collectionView collectionViewLayout] setItemSize:size];
    [_collectionView.collectionViewLayout invalidateLayout];
}

- (void)updateContent {
    NSArray *allNotifications = self.allNotifications();
    NSMutableDictionary *contentTable = [NSMutableDictionary new];

    for (id object in allNotifications) {
        NSString *identifier = (NSString *)[object performSelector:@selector(sectionIdentifier)];
        NSInteger count = 1;

        if (contentTable[identifier]) {
            count = [(Request *) contentTable[identifier] count] + 1;
        }

        Request *request = [[Request alloc] requestWithIdentifier:identifier count:count icon:self.iconForIdentifier(identifier)];

        [contentTable setObject:request forKey:identifier];
    }

    // NSMutableArray *requests = [contentTable.allValues mutableCopy];
    // [requests sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:YES]]];

    NSOrderedSet *orderedRequests = [NSOrderedSet orderedSetWithArray:contentTable.allValues];
    [self setIndexedRequests:orderedRequests];
}

@end