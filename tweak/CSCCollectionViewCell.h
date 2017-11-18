enum {
    CSCCellStyleBadge = 0,
    CSCCellStyleBelow = 1,
};
typedef NSUInteger CSCCellStyle;

enum {
    CSCCollectionStyleLS = 0,
    CSCCollectionStyleNC = 1,
};
typedef NSUInteger CSCCollectionStyle;

@interface CSCCollectionViewCell : UICollectionViewCell
@property (nonatomic, assign) CSCCollectionStyle collectionStyle;

@property (retain, nonatomic) UILabel *label;
@property (retain, nonatomic) UIImageView *iconView;
@property (retain, nonatomic) UIView *backdrop;
@property (assign, nonatomic) UIEdgeInsets selectedInsets;
@property (assign, nonatomic) UIEdgeInsets insets;
@property (assign, nonatomic) BOOL visible;

- (void)setIcon:(UIImage *)icon;
- (void)setCount:(NSString *)count;
- (void)applyChangesAnimated:(BOOL)animated;
- (void)fetchAndApplySettings;
@end