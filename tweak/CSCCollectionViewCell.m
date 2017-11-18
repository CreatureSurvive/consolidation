#import "CSCCollectionViewCell.h"
#import "CSCProvider.h"
#define prefs [CSCProvider sharedProvider]

@interface NCMaterialView : UIView
@property (assign, setter = _setSubviewsContinuousCornerRadius :, getter = _subviewsContinuousCornerRadius, nonatomic) double subviewsContinuousCornerRadius;
+ (id)materialViewWithStyleOptions:(NSUInteger)style;
@end

@implementation CSCCollectionViewCell {
    CSCCellStyle _style;

    UIColor *_badgeBackgroundColor;
    UIColor *_badgeTextColor;
    UIColor *_materialColor;
    double _badgeRadius;
    double _materialRadius;
    double _iconRadius;
}

- (id)initWithFrame:(CGRect)frame {

    if (self == [super initWithFrame:frame]) {
        CGRect bounds = CGRectMake(0.0, 0.0, frame.size.width, frame.size.height);
        [self setInsetsForFrame:frame];

        // ___ setup backdrop ______________________________________________
        Class backdropClass = NSClassFromString(@"NCMaterialView");
        if (backdropClass) {
            self.backdrop = [backdropClass materialViewWithStyleOptions:1];
            self.backdrop.frame = UIEdgeInsetsInsetRect(bounds, UIEdgeInsetsMake(1, 1, 1, 1));
            [(NCMaterialView *) self.backdrop _setSubviewsContinuousCornerRadius:bounds.size.width / 3];
        } else {
            self.backdrop = [[UIView alloc] initWithFrame:UIEdgeInsetsInsetRect(bounds, UIEdgeInsetsMake(1, 1, 1, 1))];
            self.backdrop.backgroundColor = [UIColor lightTextColor];
            self.backdrop.layer.cornerRadius = bounds.size.width / 3;
        }
        self.backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        // ___ setup imageview _____________________________________________
        self.iconView = [[UIImageView alloc] init];
        self.iconView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.iconView.contentMode = UIViewContentModeScaleAspectFit;
        self.iconView.layer.masksToBounds = YES;

        // ___ setup label _________________________________________________
        self.label = [[UILabel alloc] init];
        self.label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.label.textAlignment = NSTextAlignmentCenter;
        self.label.adjustsFontSizeToFitWidth = YES;
        self.label.layer.masksToBounds = YES;
        self.label.clipsToBounds = YES;

        // ___ add subviews ________________________________________________
        [self.contentView addSubview:self.backdrop];
        [self.contentView addSubview:self.iconView];
        [self.contentView addSubview:self.label];

        // ___ fetch preferences ___________________________________________
        [self fetchAndApplySettings];

        // ___ update frames _______________________________________________
        [self updateIconFrame];
        [self updateBadgeFrame];
        [self updateBadgeFont];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fetchAndApplySettings) name:@"kCSCPrefsChanged" object:nil];
    }
    return self;
}

#pragma mark - UIColectionViewCell

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    [self applyChangesAnimated:self.visible];
}

- (void)applyChangesAnimated:(BOOL)animated {
    void (^changes)() = ^void () {
        [self updateIconFrame];
        [self updateBadgeFrame];
        [self updateBadgeFont];
    };
    if (animated) {
        [UIView animateWithDuration:0.6 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.05 options:UIViewAnimationOptionAllowUserInteraction animations:^{ changes(); } completion:^(BOOL finished) {
            if (finished)
                [self.layer removeAllAnimations];
        }];
    } else {
        changes();
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self setSelected:NO];
    [self applyChangesAnimated:NO];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    _style = frame.size.height > frame.size.width;
}

#pragma mark - Apply Values For State

- (void)updateIconFrame {
    self.iconView.frame = [self iconRectforCellState:self.selected];
    self.iconView.layer.cornerRadius = self.iconView.frame.size.width * _iconRadius;
}

- (void)updateBadgeFrame {
    self.label.frame = [self badgeRectForCellState:self.selected];
    self.label.layer.cornerRadius = self.label.frame.size.height * _badgeRadius;
}

- (void)updateBadgeFont {
    self.label.font = [UIFont systemFontOfSize:(self.selected || _style) ? 12.0 : 9.0];
}

#pragma mark - Setters

- (void)setIcon:(UIImage *)icon {
    self.iconView.image = icon;
}

- (void)setCount:(NSString *)count {
    self.label.text = count;
}

- (void)setInsetsForFrame:(CGRect)frame {
    CGFloat height = frame.size.height, width = frame.size.width;
    if (_style) {
        self.insets = UIEdgeInsetsMake(1, 4, height - width  - 4, 4);
        self.selectedInsets = UIEdgeInsetsMake(0, 0, height - width, 0);
    } else {
        self.insets = UIEdgeInsetsMake(4, 4, 4, 4);
        self.selectedInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    }
}

#pragma mark - Rect Calculations

- (CGRect)iconRectforCellState:(BOOL)selected {
    return selected ? UIEdgeInsetsInsetRect(self.bounds, self.selectedInsets) : UIEdgeInsetsInsetRect(self.bounds, self.insets);
}

- (CGRect)badgeRectForCellState:(BOOL)selected {
    CGRect iconRect = [self iconRectforCellState:selected];
    UIEdgeInsets insets = selected ? self.selectedInsets : self.insets;
    CGFloat extraWidth = self.label.text.length ? (self.label.text.length - 1) * 4 : 0;
    CGSize size = (selected || _style) ? CGSizeMake((14 + extraWidth), 14) : CGSizeMake(10 + extraWidth, 10);

    CGRect badgeRect;
    if (_style) {
        badgeRect = CGRectMake(CGRectGetMidX(self.bounds) - (size.width / 2), CGRectGetMaxY(self.bounds) - (size.height + 4), size.width, size.height);
    } else {
        badgeRect = CGRectMake(iconRect.size.width - size.width + insets.right - selected, insets.top, size.width, size.height);
    }
    return badgeRect;
}

- (void)setCollectionStyle:(CSCCollectionStyle)style {
    _collectionStyle = style;
    [self fetchAndApplySettings];
}

- (void)fetchAndApplySettings {
    _badgeBackgroundColor = [prefs colorForKey:self.collectionStyle ? @"lsBadgeBackgroundColor" : @"ncBadgeBackgroundColor"];
    _badgeTextColor = [prefs colorForKey:self.collectionStyle ? @"lsBadgeTextColor" : @"ncBadgeTextColor"];
    _materialColor = [prefs colorForKey:self.collectionStyle ? @"lsMaterialColor" : @"ncMaterialColor"];
    _badgeRadius = [prefs doubleForKey:self.collectionStyle ? @"lsBadgeRadius" : @"ncBadgeRadius"];
    _materialRadius = [prefs doubleForKey:self.collectionStyle ? @"lsMaterialRadius" : @"ncMaterialRadius"];
    _iconRadius = [prefs doubleForKey:self.collectionStyle ? @"lsIconRadius" : @"ncIconRadius"];

    // ___ BACKDROP ___________________________________________________________________
    Class backdropClass = NSClassFromString(@"NCMaterialView");
    if (backdropClass)
        [(NCMaterialView *) self.backdrop _setSubviewsContinuousCornerRadius:self.bounds.size.width * _materialRadius];
    else
        self.backdrop.layer.cornerRadius = [self iconRectforCellState:self.selected].size.width * _materialRadius;

    // ___ BADGE ______________________________________________________________________
    self.label.textColor = _badgeTextColor;
    self.label.backgroundColor = _badgeBackgroundColor;
    self.label.layer.cornerRadius = self.label.frame.size.height * _badgeRadius;

    // ___ ICON _______________________________________________________________________
    self.iconView.layer.cornerRadius = self.iconView.frame.size.width * _iconRadius;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end