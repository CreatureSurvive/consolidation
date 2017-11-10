#import "CSCCollectionViewCell.h"

@implementation CSCCollectionViewCell

- (id)initWithFrame:(CGRect)frame {

    if (self == [super initWithFrame:frame]) {
        CGRect bounds = CGRectMake(0.0, 0.0, frame.size.width, frame.size.height);
        self.insets = UIEdgeInsetsMake(4, 4, 4, 4);
        self.selectedInsets = UIEdgeInsetsMake(0, -1, 0, -1);

        self.backdrop = [[UIView alloc] initWithFrame:bounds];
        self.backdrop.backgroundColor = [UIColor lightTextColor];
        self.backdrop.layer.cornerRadius = bounds.size.width / 3;

        // setup imageview
        self.iconView = [[UIImageView alloc] initWithFrame:[self iconRectforCellState:NO]];
        self.iconView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.iconView.contentMode = UIViewContentModeScaleAspectFill;
        self.iconView.clipsToBounds = YES;
        self.iconView.layer.masksToBounds = YES;

        // setup label
        self.label = [[UILabel alloc] initWithFrame:[self badgeRectForCellState:NO]];
        self.label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.label.textAlignment = NSTextAlignmentCenter;
        self.label.textColor = [UIColor darkTextColor];
        self.label.font = [UIFont systemFontOfSize:10.0];
        self.label.backgroundColor = [UIColor colorWithRed:1.00 green:0.31 blue:0.31 alpha:1.0];
        self.label.adjustsFontSizeToFitWidth = YES;
        self.label.layer.masksToBounds = YES;
        self.label.layer.cornerRadius = self.label.frame.size.height / 3;

        // add subviews
        [self.contentView addSubview:self.backdrop];
        [self.contentView addSubview:self.iconView];
        [self.contentView addSubview:self.label];

    }
    return self;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];

    [UIView transitionWithView:self.iconView
                      duration:0.15f
                       options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
        [self updateIconFrame];
        [self updateBadgeFrame];
    } completion:nil];
}

- (void)updateIconFrame {
    self.iconView.frame = [self iconRectforCellState:self.selected];
    self.iconView.layer.cornerRadius = self.iconView.frame.size.width / 3;
}

- (void)updateBadgeFrame {
    self.label.frame = [self badgeRectForCellState:self.selected];
    self.label.layer.cornerRadius = self.label.frame.size.height / 3;
}

- (void)setIcon:(UIImage *)icon {
    self.iconView.image = icon;
}

- (void)setCount:(NSString *)count {
    self.label.text = count;
}

- (CGRect)iconRectforCellState:(BOOL)selected {
    return selected ? UIEdgeInsetsInsetRect(self.bounds, self.selectedInsets) : UIEdgeInsetsInsetRect(self.bounds, self.insets);
}

- (CGRect)badgeRectForCellState:(BOOL)selected {
    CGRect iconRect = [self iconRectforCellState:selected];
    UIEdgeInsets insets = selected ? self.selectedInsets : self.insets;
    CGFloat extraWidth = self.label.text.length ? (self.label.text.length - 1) * 4 : 0;
    CGSize size = selected ? CGSizeMake((14 + extraWidth), 14) : CGSizeMake(10 + extraWidth, 10);
    return CGRectMake(iconRect.size.width - size.width + insets.right - selected, insets.top, size.width, size.height);
}

@end