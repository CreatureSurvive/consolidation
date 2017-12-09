#import "CSCCollectionViewController.h"
#import "CSCIconProvider.h"
#import "CSCFeedbackGenerator.h"

@interface Request : NSObject
@property(retain, nonatomic) NSIndexPath *index;
@property(retain, nonatomic) NSString *identifier;
@property(assign, nonatomic) NSInteger count;
@property(retain, nonatomic) UIImage *icon;
@property(retain, nonatomic) NSDate *timestamp;
@end

@implementation Request

- (id)requestWithIdentifier:(NSString *)identifier count:(NSInteger)count timestamp:(NSDate *)timestamp icon:(UIImage *)icon {
    if (self == [super init]) {
        self.identifier = identifier;
        self.count = count;
        self.timestamp = timestamp;
        self.icon = icon;
    }
    return self;
}

@end

@implementation CSCCollectionViewController {
    CSCIconProvider *_iconProvider;
}

// - (void)dealloc {
//     [[NSNotificationCenter defaultCenter] removeObserver:self];
// }

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

    _iconProvider = [CSCIconProvider sharedProvider];

    // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setCollectionStyle:) name:@"kCSCPrefsChanged" object:@(self.collectionStyle)];
}

#pragma mark - UICollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _indexedRequests.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CSCCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"notificationSectionCell" forIndexPath:indexPath];
    [cell setCollectionStyle:self.collectionStyle];

    if (_selectedIndexPath != indexPath) {
        [_collectionView deselectItemAtIndexPath:indexPath animated:NO];
    } else {
        [_collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
        self.setCurrentIdentifier([self requestAtIndexPath:_selectedIndexPath].identifier);
    }

    Request *request = [self requestAtIndexPath:indexPath];
    [cell setCount:@(request.count).stringValue];
    [cell setIcon:request.icon];
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    [(CSCCollectionViewCell *) cell setSelected:_selectedIndexPath == indexPath];
    [(CSCCollectionViewCell *) cell setVisible:YES];
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    [(CSCCollectionViewCell *) cell setVisible:NO];
    [(CSCCollectionViewCell *) cell setSelected:_selectedIndexPath == indexPath];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *indexPaths = collectionView.indexPathsForSelectedItems;
    _selectedIndexPath = indexPath;
    self.setCurrentIdentifier([self requestAtIndexPath:_selectedIndexPath].identifier);
    for (NSIndexPath *otherIndexPath in indexPaths) {
        if ([otherIndexPath isEqual:indexPath]) continue;
        [collectionView deselectItemAtIndexPath:otherIndexPath animated:NO];
    }
    [self playFeedbackIfNecessary];
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

- (NSIndexPath *)indexPathForIdentifier:(NSString *)identifier {
    NSInteger row = 0;
    NSIndexPath *index;
    for (Request *request in _indexedRequests) {
        if ([request.identifier isEqualToString:identifier]) {
            index = [NSIndexPath indexPathForRow:row inSection:0];
        }
    }
    return index;
}

- (NSString *)countForCellAtIndexPath:(NSIndexPath *)indexPath {
    return @([self requestAtIndexPath:indexPath].count).stringValue;
}

- (UIImage *)iconForCellAtIndexPath:(NSIndexPath *)indexPath {
    return [_iconProvider iconForBundleIdentifier:[self requestAtIndexPath:indexPath].identifier];
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

- (void)setCollectionStyle:(CSCCollectionStyle)style {
    _collectionStyle = style;
    for (CSCCollectionViewCell *cell in [_collectionView visibleCells]) {
        [cell setCollectionStyle:self.collectionStyle];
    }
}

- (void)updateContent {
    NSArray *allNotifications = self.allNotifications();
    NSMutableDictionary *contentTable = [NSMutableDictionary new];
    NSString *identifier;
    NSDate *timestamp;

    for (id object in allNotifications) {
        identifier = (NSString *)[object performSelector:@selector(sectionIdentifier)];
        timestamp = (NSDate *)[object performSelector:@selector(timestamp)];
        NSInteger count = 1;

        if (contentTable[identifier]) {
            Request *request = (Request *)contentTable[identifier];
            if ([request.timestamp compare:request.timestamp] == NSOrderedDescending) timestamp = request.timestamp;
            count = request.count + 1;
        }

        Request *request = [[Request alloc] requestWithIdentifier:identifier count:count timestamp:timestamp icon:[_iconProvider iconForBundleIdentifier:identifier]];
        [contentTable setObject:request forKey:identifier];
    }

    if (contentTable.count > 1 && self.showAllSection) {
        identifier = @"-showAll";
        Request *request = [[Request alloc] requestWithIdentifier:identifier count:allNotifications.count timestamp:[NSDate date] icon:[_iconProvider iconForBundleIdentifier:identifier]];
        [contentTable setObject:request forKey:identifier];
    }

    NSMutableArray *requests = [contentTable.allValues mutableCopy];
    [requests sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO]]];

    NSOrderedSet *orderedRequests = [NSOrderedSet orderedSetWithArray:requests];
    [self setIndexedRequests:orderedRequests];
}

- (void)applyIndexPathsToRequests {
    NSInteger row = 0;
    for (Request *request in _indexedRequests) {
        request.index = [NSIndexPath indexPathForRow:row inSection:0];
        row++;
    }
}

- (void)selectItemWithIdentifier:(NSString *)identifier animated:(BOOL)animated {
    NSIndexPath *index = [self indexPathForIdentifier:identifier];
    if (index) {
        [_collectionView selectItemAtIndexPath:index animated:animated scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
        _selectedIndexPath = index;
        self.setCurrentIdentifier([self requestAtIndexPath:index].identifier);
    } else {
        [_collectionView deselectItemAtIndexPath:_selectedIndexPath animated:animated];
        _selectedIndexPath = nil;
        self.setCurrentIdentifier(nil);
    }
}

- (void)updateContentAndSelectItemWithIdentifier:(NSString *)identifier animated:(BOOL)animated {
    [self updateContent];
    [self selectItemWithIdentifier:identifier animated:animated];
}

- (void)updateVisibleCellsAnimated:(BOOL)animated {
    for (CSCCollectionViewCell *cell in [_collectionView visibleCells]) {
        [cell applyChangesAnimated:animated];
    }
}

- (void)playFeedbackIfNecessary {

    Class feedbackClass = NSClassFromString(@"UISelectionFeedbackGenerator");
    if (feedbackClass) {
        UISelectionFeedbackGenerator *generator = [[NSClassFromString(@"UISelectionFeedbackGenerator") alloc] init];
        [generator performSelector:@selector(prepare)];
        [generator performSelector:@selector(selectionChanged)];
        generator = nil;
    }
}

@end