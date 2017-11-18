enum {
    FeedbackTypeSelection,
    FeedbackTypeImpactLight,
    FeedbackTypeImpactMedium,
    FeedbackTypeImpactHeavy,
    FeedbackTypeNotificationSuccess,
    FeedbackTypeNotificationWarning,
    FeedbackTypeNotificationError
};
typedef NSUInteger FeedbackType;

@interface UIFeedbackGenerator : NSObject
- (void)prepare;
@end

@interface UISelectionFeedbackGenerator : UIFeedbackGenerator
- (void)selectionChanged;
@end

@interface CSCFeedbackGenerator : NSObject

@end