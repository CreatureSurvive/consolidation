#import "CSCCollectionViewCell.h"
#import "CSCProvider.h"
#import "colorbadges_api.h"
#import <dlfcn.h>
#define prefs [CSCProvider sharedProvider]

@interface _UIBackdropView : UIView
@property (nonatomic, retain) UIView *colorTintView;
@end

@interface NCMaterialView : UIView
@property (assign, setter = _setSubviewsContinuousCornerRadius :, getter = _subviewsContinuousCornerRadius, nonatomic) double subviewsContinuousCornerRadius;
+ (NCMaterialView *)materialViewWithStyleOptions:(NSUInteger)styleOptions;

// noctis support
- (void)setUseLQDCCStyle:(BOOL)enableNoctis;
- (void)setDarkModeEnabled:(BOOL)noctisIsEnabled;
@end

@implementation CSCCollectionViewCell {
    CSCCellStyle _style;

    UIColor *_badgeBackgroundColor;
    UIColor *_badgeTextColor;
    UIColor *_materialColor;
    UIColor *_materialColorUnselected;
    double _badgeRadius;
    double _materialRadius;
    double _iconRadius;
    double _badgeScale;
    BOOL _colorbadgesEnabled;
    BOOL _springAnimation;
    Class _colorbadges;
    Class _backdropClass;
}

- (id)initWithFrame:(CGRect)frame {

    if (self == [super initWithFrame:frame]) {
        CGRect bounds = CGRectMake(0.0, 0.0, frame.size.width, frame.size.height);
        [self setInsetsForFrame:frame];

        // ___ setup backdrop ______________________________________________
        _backdropClass = NSClassFromString(@"NCMaterialView");
        if (_backdropClass) {
            self.backdrop = [_backdropClass materialViewWithStyleOptions:1];
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

        // ___ color badges ________________________________________________
        dlopen("/Library/MobileSubstrate/DynamicLibraries/ColorBadges.dylib", RTLD_LAZY);
        _colorbadges = NSClassFromString(@"ColorBadges");
        _colorbadgesEnabled = (_colorbadges && [_colorbadges isEnabled]);

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

- (BOOL)isSelectedCell {
    return _springAnimation ? self.selected : NO;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    [self applyChangesAnimated:self.visible];
}

- (void)applyChangesAnimated:(BOOL)animated {
    void (^changes)() = ^void () {
        [self updateSelectionColor];
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
    self.iconView.frame = [self iconRectforCellState:self.isSelectedCell];
    self.iconView.layer.cornerRadius = self.iconView.frame.size.width * _iconRadius;
}

- (void)updateBadgeFrame {
    self.label.frame = [self badgeRectForCellState:self.isSelectedCell];
    self.label.layer.cornerRadius = self.label.frame.size.height * _badgeRadius;
}

- (void)updateBadgeFont {
    self.label.font = [UIFont systemFontOfSize:((self.isSelectedCell || _style) ? 13.0 : 11.0) * _badgeScale];
}

- (void)updateSelectionColor {
    if (_backdropClass) {
        NCMaterialView *materialBackdrop = (NCMaterialView *)self.backdrop;
        [materialBackdrop _setSubviewsContinuousCornerRadius:self.bounds.size.width * _materialRadius];
        [[(_UIBackdropView *)[materialBackdrop valueForKey:@"_backdropView"] colorTintView] setBackgroundColor:[self.selected ? _materialColor : _materialColorUnselected colorWithAlphaComponent:1]];
        materialBackdrop.alpha = [self.selected ? _materialColor : _materialColorUnselected alpha];
    } else {
        self.backdrop.layer.cornerRadius = [self iconRectforCellState:self.selected].size.width * _materialRadius;
        self.backdrop.backgroundColor = self.selected ? _materialColor : _materialColorUnselected;
    }
}

#pragma mark - Setters

- (void)setIcon:(UIImage *)icon {
    self.iconView.image = icon;
    [self updateColorBadges];
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
    double sizeMultiplier = 5 * _badgeScale, baseSizeBelow = 14 * _badgeScale, baseSizeCorner = 12 * _badgeScale;
    CGRect iconRect = [self iconRectforCellState:selected];
    UIEdgeInsets insets = selected ? self.selectedInsets : self.insets;
    CGFloat extraWidth = self.label.text.length ? (self.label.text.length - 1) * sizeMultiplier : 0;
    CGSize size = (selected || _style) ? CGSizeMake((baseSizeBelow + extraWidth), baseSizeBelow) : CGSizeMake(baseSizeCorner + extraWidth, baseSizeCorner);

    CGRect badgeRect;
    if (_style) {
        badgeRect = CGRectMake(CGRectGetMidX(self.bounds) - (size.width / 2), CGRectGetMaxY(self.bounds) - (size.height + 3), size.width, size.height);
    } else {
        badgeRect = CGRectMake(iconRect.size.width - (size.width / 1.3)+ insets.right - selected, insets.top - (size.height / 4.5), size.width, size.height);
    }
    return badgeRect;
}

- (void)setCollectionStyle:(CSCCollectionStyle)style {
    _collectionStyle = style;
    [self fetchAndApplySettings];
}

- (void)fetchAndApplySettings {
    _springAnimation = [prefs boolForKey:self.collectionStyle ? @"ncSpringAnimation" : @"lsSpringAnimation"];
    _badgeBackgroundColor = [prefs colorForKey:self.collectionStyle ? @"ncBadgeBackgroundColor" : @"lsBadgeBackgroundColor"];
    _badgeTextColor = [prefs colorForKey:self.collectionStyle ? @"ncBadgeTextColor" : @"lsBadgeTextColor"];
    _materialColor = [prefs colorForKey:self.collectionStyle ? @"ncMaterialColor" : @"lsMaterialColor"];
    _materialColorUnselected = [prefs colorForKey:self.collectionStyle ? @"ncMaterialColorUnselected" : @"lsMaterialColorUnselected"];
    _badgeRadius = [prefs doubleForKey:self.collectionStyle ? @"ncBadgeRadius" : @"lsBadgeRadius"];
    _materialRadius = [prefs doubleForKey:self.collectionStyle ? @"ncMaterialRadius" : @"lsMaterialRadius"];
    _iconRadius = [prefs doubleForKey:self.collectionStyle ? @"ncIconRadius" : @"lsIconRadius"];
    _badgeScale = [prefs doubleForKey:self.collectionStyle ? @"ncBadgeScale" : @"lsBadgeScale"];

    // ___ BACKDROP ___________________________________________________________________
    [self updateSelectionColor];

    // ___ BADGE ______________________________________________________________________
    // ___ ColorBadges support ________________________________________________________
    if (_colorbadgesEnabled) {
        [self updateColorBadges];
    } else {
        self.label.textColor = _badgeTextColor;
        self.label.backgroundColor = _badgeBackgroundColor;
    }
    self.label.layer.cornerRadius = self.label.frame.size.height * _badgeRadius;

    // ___ ICON _______________________________________________________________________
    self.iconView.layer.cornerRadius = self.iconView.frame.size.width * _iconRadius;
}

- (void)updateColorBadges {
    if (_colorbadgesEnabled) {
        int badgeColor = [[_colorbadges sharedInstance] colorForImage:self.iconView.image];
        self.label.backgroundColor = UIColorFromRGB(badgeColor);

        if ([_colorbadges areBordersEnabled])
            self.label.layer.borderWidth = 1.0;

        if ([_colorbadges isDarkColor:badgeColor]) {
            self.label.layer.borderColor = [UIColor lightTextColor].CGColor;
            self.label.textColor = [UIColor lightTextColor];
        } else {
            self.label.layer.borderColor = [UIColor darkTextColor].CGColor;
            self.label.textColor = [UIColor darkTextColor];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end