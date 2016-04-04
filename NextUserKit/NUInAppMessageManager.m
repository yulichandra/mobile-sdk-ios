//
//  NUInAppMessageManager.m
//  NextUserKit
//
//  Created by Dino on 3/9/16.
//  Copyright © 2016 NextUser. All rights reserved.
//

#import "NUInAppMessageManager.h"
#import "NUPushMessage.h"
#import "NUIAMNotificationView.h"
#import "NUIAMContentView.h"
#import "NUIAMUITheme.h"
#import "NUDDLog.h"

#define kIAMNotificationViewSideInset 20
#define kIAMNotificationViewHeight 75
#define kIAMNotificationViewCornerRadius 5

@interface NUInAppMessageManager () <NUIAMNotificationViewDelegate, NUIAMContentViewDelegate>

@property (nonatomic) NUIAMNotificationView *notificationView;
@property (nonatomic) NUIAMContentView *contentView;

@property (nonatomic) NSTimer *notificationViewDismissTimer;
@property (nonatomic) BOOL isIAMNotificationPresented;

@end

@implementation NUInAppMessageManager

#pragma mark - Public

+ (instancetype)sharedManager
{
    static NUInAppMessageManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NUInAppMessageManager alloc] init];
    });
    
    return instance;
}

- (void)showPushMessage:(NUPushMessage *)message skipNotificationUI:(BOOL)skipNotificationUI
{
    [self showIAMViewForMessage:message skipNotificationUI:skipNotificationUI];
}

#pragma mark - Private

- (void)initializeIAMViewsOnce
{
    if (_notificationView == nil) {
        
        // 1. grab the parent view
        UIView *parentView = [self parentView];
        
        // 2. calculate notification view frame
        CGFloat notificationSideInsets = kIAMNotificationViewSideInset;
        CGRect notificationViewFrame = CGRectMake(notificationSideInsets,
                                                  0,
                                                  parentView.bounds.size.width - 2*notificationSideInsets,
                                                  kIAMNotificationViewHeight);
        
        // 3. create notification view
        NUIAMNotificationView *notificationView = [[NUIAMNotificationView alloc] initWithFrame:notificationViewFrame];
        notificationView.delegate = self;
        
        // 4. style notification view with mask (bottom rounded corners)
        UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:notificationView.bounds
                                                       byRoundingCorners:(UIRectCornerBottomLeft|UIRectCornerBottomRight)
                                                             cornerRadii:CGSizeMake(kIAMNotificationViewCornerRadius, kIAMNotificationViewCornerRadius)];
        
        CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
        maskLayer.frame = notificationView.bounds;
        maskLayer.path = maskPath.CGPath;
        notificationView.layer.mask = maskLayer;
        
        // 5. calculate content view frame
        CGRect contentViewFrame = parentView.bounds;
        
        // 6. create content view
        NUIAMContentView *contentView = [[NUIAMContentView alloc] initWithFrame:contentViewFrame];
        contentView.delegate = self;
        
        // 7. assign values to ivars
        _contentView = contentView;
        _notificationView = notificationView;
    }
}

- (void)prepareIAMViewsForMessage:(NUPushMessage *)message
{
    // 1. create notification & content views
    [self initializeIAMViewsOnce];
    
    _notificationView.transform = CGAffineTransformIdentity;
    _contentView.transform = CGAffineTransformIdentity;
    
    _notificationView.message = message;
    _contentView.message = message;
    
    // 2. add views to parent view
    UIView *parentView = [self parentView];
    [parentView addSubview:_notificationView];
    [parentView addSubview:_contentView];
    
    // 3. hide content view from screen
    CGRect contentViewFrame = CGRectMake(0,
                                         -_contentView.bounds.size.height,
                                         _contentView.bounds.size.width,
                                         _contentView.bounds.size.height);
    _contentView.frame = contentViewFrame;
}

- (UIView *)parentView
{
    return [[[[[UIApplication sharedApplication] delegate] window] rootViewController] view];
}

#pragma mark - IAM Show/Hide

- (void)showIAMViewForMessage:(NUPushMessage *)message skipNotificationUI:(BOOL)skipNotificationUI
{
    if (!_isIAMNotificationPresented) {
        
        _isIAMNotificationPresented = YES;
        
        [self prepareIAMViewsForMessage:message];
        
        if (skipNotificationUI) {
            [self showContentViewAnimated:NO];
        } else {
            [self revealNotificationViewWithCompletion:^{
                [self scheduleNotificationDismissTimer];
            }];
        }
        
    } else {
        DDLogWarn(@"Already showing IAM!");
    }
}

- (void)dismissIAMView
{
    [self invalidateNotificationDismissTimer];
    [self unrevealNotificationViewWithCompletion:^{
        _isIAMNotificationPresented = NO;
    }];
}

#pragma mark - Notification View Reveal/Unreveal

- (void)revealNotificationViewWithCompletion:(void(^)())completion
{
    // animate notification view from screen top
    CGFloat xOffset = kIAMNotificationViewSideInset;
    CGRect notificationViewEndFrame = CGRectMake(xOffset,
                                                 0,
                                                 _notificationView.bounds.size.width,
                                                 _notificationView.bounds.size.height);
    
    CGRect notificationViewStartFrame = CGRectMake(xOffset,
                                                   -_notificationView.bounds.size.height,
                                                   _notificationView.bounds.size.width,
                                                   _notificationView.bounds.size.height);
    
    _notificationView.frame = notificationViewStartFrame;
    [UIView animateWithDuration:0.3
                          delay:0
                        options:0
                     animations:^{
                         _notificationView.frame = notificationViewEndFrame;
                     } completion:^(BOOL finished) {
                         completion();
                     }];
}

- (void)unrevealNotificationViewWithCompletion:(void(^)())completion
{
    NSAssert(_notificationView != nil, @"notification view can not be nil");
    
    // hide from screen (move up) both notification & content views
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0, -_notificationView.bounds.size.height);
    
    [UIView animateWithDuration:0.3
                          delay:0
                        options:0
                     animations:^{
                         _notificationView.transform = transform;
                         _contentView.transform = transform;
                     } completion:^(BOOL finished) {
                         [_notificationView removeFromSuperview];
                         [_contentView removeFromSuperview];
                         completion();
                     }];
}

#pragma mark - Content View Show/Hide

- (void)showContentViewAnimated:(BOOL)animated
{
    [self invalidateNotificationDismissTimer];
    
    UIView *parentView = [self parentView];
    
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0, parentView.bounds.size.height);
    CGAffineTransform notificationViewEndTransform = transform;
    CGAffineTransform contentViewEndTransform = transform;
    
    if (animated) {
        [UIView animateWithDuration:0.3
                              delay:0
                            options:0
                         animations:^{
                             _notificationView.transform = notificationViewEndTransform;
                             _contentView.transform = contentViewEndTransform;
                         } completion:nil];
    } else {
        _notificationView.transform = notificationViewEndTransform;
        _contentView.transform = contentViewEndTransform;
    }
}

- (void)resetIAMViewsOnTouchEnd
{
    CGAffineTransform notificationViewEndTransform = CGAffineTransformIdentity;
    CGAffineTransform contentViewEndTransform = CGAffineTransformIdentity;
    
    [UIView animateWithDuration:0.3
                          delay:0
                        options:0
                     animations:^{
                         _notificationView.transform = notificationViewEndTransform;
                         _contentView.transform = contentViewEndTransform;
                     } completion:^(BOOL finished) {
                         [self scheduleNotificationDismissTimer];
                     }];
}

#pragma mark - Notification Dismiss Timer

- (void)scheduleNotificationDismissTimer
{
    _notificationViewDismissTimer = [NSTimer scheduledTimerWithTimeInterval:10
                                                                     target:self
                                                                   selector:@selector(notificationDismissTimerFired:)
                                                                   userInfo:nil
                                                                    repeats:NO];
}

- (void)invalidateNotificationDismissTimer
{
    [_notificationViewDismissTimer invalidate];
    _notificationViewDismissTimer = nil;
}

- (void)notificationDismissTimerFired:(NSTimer *)timer
{
    [self dismissIAMView];
}

#pragma mark - IAM Content View Delegate

- (void)IAMContentViewDidDismiss:(NUIAMContentView *)view
{
    [self dismissIAMView];
}

#pragma mark - IAM Notification View Delegate

- (void)IAMNotificationView:(NUIAMNotificationView *)view didTapWithRecognizer:(UITapGestureRecognizer *)gesture
{
    [self showContentViewAnimated:YES];
}

- (void)IAMNotificationView:(NUIAMNotificationView *)view didPanWithRecognizer:(UIPanGestureRecognizer *)gesture
{
    UIView *parentView = [self parentView];
    CGPoint translation = [gesture translationInView:parentView];

    switch (gesture.state) {
        case UIGestureRecognizerStatePossible:
            break;
        case UIGestureRecognizerStateBegan:
            
            [self invalidateNotificationDismissTimer];
            
            break;
        case UIGestureRecognizerStateChanged:
        {
            CGAffineTransform transform = CGAffineTransformMakeTranslation(0, translation.y);
            _notificationView.transform = transform;
            _contentView.transform = transform;
        }
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            break;
        case UIGestureRecognizerStateRecognized:
        {
            BOOL shouldShowContentViewFully = translation.y >= parentView.bounds.size.height/2.0;
            BOOL shouldUnrevealNotificationView = translation.y < (-_notificationView.bounds.size.height/2.0);
            
            if (shouldShowContentViewFully) {
                [self showContentViewAnimated:YES];
            } else if (shouldUnrevealNotificationView) {
                [self dismissIAMView];
            } else {
                [self resetIAMViewsOnTouchEnd];
            }
        }
            break;
    }
}

@end
