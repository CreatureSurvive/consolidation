@interface CSCCollectionViewCell : UICollectionViewCell

@property (retain, nonatomic) NSString *identifier;
@property (retain, nonatomic) UILabel *label;
@property (retain, nonatomic) UIImageView *iconView;
@property (retain, nonatomic) UIView *backdrop;
@property (assign, nonatomic) UIEdgeInsets selectedInsets;
@property (assign, nonatomic) UIEdgeInsets insets;

- (void)setIcon:(UIImage *)icon;
- (void)setCount:(NSString *)count;
@end