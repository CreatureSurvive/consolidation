#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

const CGFloat pullToClearSize = 30;
const CGFloat pullToClearThreshold = 35;

@interface PHPullToClearView : UIView {
    CAShapeLayer *circleLayer, *xLayer;
    NSInteger _style;
}

@property BOOL xVisible;
@property (nonatomic, copy) void (^clearBlock)();

- (id)initWithStyle:(NSInteger)style;
- (void)didScroll:(UIScrollView *)scrollView;
- (void)didEndDragging:(UIScrollView *)scrollView;

@end
