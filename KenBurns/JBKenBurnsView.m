//
//  KenBurnsView.m
//  KenBurns
//
//  Created by Javier Berlana on 9/23/11.
//  Copyright (c) 2011, Javier Berlana
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this 
//  software and associated documentation files (the "Software"), to deal in the Software 
//  without restriction, including without limitation the rights to use, copy, modify, merge, 
//  publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
//  to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies 
//  or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
//  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
//  PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
//  FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
//  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
//  IN THE SOFTWARE.
//

#import "JBKenBurnsView.h"
#include <stdlib.h>

#define enlargeRatio 1.1
#define imageBufer 3

enum JBSourceMode {
    JBSourceModeImages,
    JBSourceModeURLs,
    JBSourceModePaths
};

// Private interface
@interface JBKenBurnsView (){
    NSMutableArray *_imagesArray;
    CGFloat _showImageDuration;
    NSInteger _currentIndex;
    BOOL _shouldLoop;
    BOOL _isLandscape;

    NSTimer *_nextImageTimer;
    enum JBSourceMode _sourceMode;
}

@property (nonatomic) int currentImage;
@property (strong, atomic) NSArray *replacementContent;

@end


@implementation JBKenBurnsView

- (void) replaceData:(NSArray *)newContent
{
    //for now only replac makes sense. TODO check how to do a lock
    self.replacementContent=newContent;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib
{
    [self setup];
}

- (void)setup
{
    self.backgroundColor = [UIColor clearColor];
    self.layer.masksToBounds = YES;
}

- (void) animateWithImagePaths:(NSArray *)imagePaths transitionDuration:(float)duration loop:(BOOL)shouldLoop isLandscape:(BOOL)isLandscape
{
    _sourceMode = JBSourceModePaths;
    [self _startAnimationsWithData:imagePaths transitionDuration:duration loop:shouldLoop isLandscape:isLandscape];
}

- (void) animateWithImageUrls:(NSArray *)imagePaths transitionDuration:(float)duration loop:(BOOL)shouldLoop isLandscape:(BOOL)isLandscape
{
    _sourceMode = JBSourceModeURLs;
    [self _startAnimationsWithData:imagePaths transitionDuration:duration loop:shouldLoop isLandscape:isLandscape];
}


- (void) animateWithImages:(NSArray *)images transitionDuration:(float)duration loop:(BOOL)shouldLoop isLandscape:(BOOL)isLandscape {
    _sourceMode = JBSourceModeImages;
    [self _startAnimationsWithData:images transitionDuration:duration loop:shouldLoop isLandscape:isLandscape];
}

- (void)_startAnimationsWithData:(NSArray *)data transitionDuration:(float)duration loop:(BOOL)shouldLoop isLandscape:(BOOL)isLandscape
{
    _imagesArray        = [data mutableCopy];
    _showImageDuration  = duration;
    _shouldLoop         = shouldLoop;
    _isLandscape        = isLandscape;

    // start at 0
    _currentIndex       = -1;

    _nextImageTimer = [NSTimer scheduledTimerWithTimeInterval:duration target:self selector:@selector(nextImage) userInfo:nil repeats:YES];
    [_nextImageTimer fire];
}

- (void)nextImage {
    _currentIndex++;
    
    if (self.replacementContent) {
        _imagesArray = [self.replacementContent mutableCopy];
        self.replacementContent=nil;
        _currentIndex=0;
    }
    
    if (_currentIndex == _imagesArray.count) {
        if (_shouldLoop) {
            _currentIndex = 0;
        }else {
            if ([[self subviews] count] > 0){
                __block UIView *oldImageView = [[self subviews] objectAtIndex:0];
                
            
            [UIView transitionWithView:oldImageView
                              duration:10.0
                               options:UIViewAnimationOptionBeginFromCurrentState
                            animations:^{
                                            oldImageView.alpha=0.0;
                                        }
                            completion:^(BOOL finished){
                                            [oldImageView removeFromSuperview];
                                            oldImageView = nil;
                                            if ([_delegate respondsToSelector:@selector(didFinishAllAnimations)])
                                                [_delegate didFinishAllAnimations];
                                        }];
            }
            [_nextImageTimer invalidate];
            return;
        }
    }


    UIImage *image = nil;
    switch (_sourceMode) {
        case JBSourceModeImages:
            image = _imagesArray[_currentIndex];
            break;

        case JBSourceModePaths:
            image = [UIImage imageWithContentsOfFile:_imagesArray[_currentIndex]];
            break;
        case JBSourceModeURLs:
            image = [UIImage imageWithData:[NSData dataWithContentsOfURL:_imagesArray[_currentIndex]]];
            break;
    }

    UIImageView *imageView = nil;
    
    float resizeRatio   = -1;
    //float widthDiff     = -1;
    //float heightDiff    = -1;
    float originX       = -1;
    float originY       = -1;
    float zoomInX       = -1;
    float zoomInY       = -1;
    float moveX         = -1;
    float moveY         = -1;
    float frameWidth    = _isLandscape ? self.bounds.size.width: self.bounds.size.height;
    float frameHeight   = _isLandscape ? self.bounds.size.height: self.bounds.size.width;
    
    //changed resizing logic so that imag always fills screen
    //the original logic failed for me in case of portrait mode
    //photos, e.g. 768 width, 1024 height
    float scaleX=frameWidth/image.size.width;
    float scaleY=frameHeight/image.size.height;
    resizeRatio=MAX(scaleX, scaleY);
    
    // Resize the image.
    float optimusWidth  = (image.size.width * resizeRatio) * enlargeRatio;
    float optimusHeight = (image.size.height * resizeRatio) * enlargeRatio;
    imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, optimusWidth, optimusHeight)];
    imageView.backgroundColor = [UIColor blackColor];
    
    // Calcule the maximum move allowed.
    float maxMoveX = optimusWidth - frameWidth;
    float maxMoveY = optimusHeight - frameHeight;
    
    //here is a bug. If you want to use rotation use
    //float rotation = (float)(arc4random() % 9) / 100;
    //did not know what working rotation could break so left it unfixed
    float rotation = (arc4random() % 9) / 100;
    
    switch (arc4random() % 4) {
        case 0:
            originX = 0;
            originY = 0;
            zoomInX = 1.25;
            zoomInY = 1.25;
            moveX   = -maxMoveX;
            moveY   = -maxMoveY;
            break;
            
        case 1:
            originX = 0;
            originY = frameHeight - optimusHeight;
            zoomInX = 1.10;
            zoomInY = 1.10;
            moveX   = -maxMoveX;
            moveY   = maxMoveY;
            break;
            
        case 2:
            originX = frameWidth - optimusWidth;
            originY = 0;
            zoomInX = 1.30;
            zoomInY = 1.30;
            moveX   = maxMoveX;
            moveY   = -maxMoveY;
            break;
            
        case 3:
            originX = frameWidth - optimusWidth;
            originY = frameHeight - optimusHeight;
            zoomInX = 1.20;
            zoomInY = 1.20;
            moveX   = maxMoveX;
            moveY   = maxMoveY;
            break;
            
        default:
            NSLog(@"Unknown random number found in JBKenBurnsView _animate");
            break;
    }
    
    NSLog(@"W: IW:%f OW:%f FW:%f MX:%f",image.size.width, optimusWidth, frameWidth, maxMoveX);
    NSLog(@"H: IH:%f OH:%f FH:%f MY:%f\n",image.size.height, optimusHeight, frameHeight, maxMoveY);
    
    CALayer *picLayer    = [CALayer layer];
    picLayer.contents    = (id)image.CGImage;
    picLayer.anchorPoint = CGPointMake(0, 0); 
    picLayer.bounds      = CGRectMake(0, 0, optimusWidth, optimusHeight);
    picLayer.position    = CGPointMake(originX, originY);
    
    [imageView.layer addSublayer:picLayer];
    
    CATransition *animation = [CATransition animation];
    [animation setDuration:1];
    [animation setType:kCATransitionFade];
    [[self layer] addAnimation:animation forKey:nil];
    
    // Remove the previous view
    if ([[self subviews] count] > 0){
        UIView *oldImageView = [[self subviews] objectAtIndex:0];
        [oldImageView removeFromSuperview];
        oldImageView = nil;
    }
    
    [self addSubview:imageView];
    
    // Generates the animation
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:_showImageDuration + 2];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
    CGAffineTransform rotate    = CGAffineTransformMakeRotation(rotation);
    CGAffineTransform moveRight = CGAffineTransformMakeTranslation(moveX, moveY);
    CGAffineTransform combo1    = CGAffineTransformConcat(rotate, moveRight);
    CGAffineTransform zoomIn    = CGAffineTransformMakeScale(zoomInX, zoomInY);
    CGAffineTransform transform = CGAffineTransformConcat(zoomIn, combo1);
    imageView.transform = transform;
    [UIView commitAnimations];

    [self _notifyDelegate];

   }

- (void) _notifyDelegate
{
    if (_delegate) {
        if([_delegate respondsToSelector:@selector(didShowImageAtIndex:)])
        {
            [_delegate didShowImageAtIndex:_currentIndex];
        }      
        
        
    }
    
}

@end
