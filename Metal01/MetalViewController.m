//
//  MetalViewController.m
//  Metal01
//
//  Created by Andrei Marincas on 3/1/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import "MetalViewController.h"
#import "MetalView.h"
#import "MetalRenderer.h"

@interface MetalViewController ()
{
    __weak MetalView *_metalView;
    
    CADisplayLink *_displayLink;
    BOOL _renderLoopPaused;
    
    MetalRenderer *_renderer;
}

@end

@implementation MetalViewController

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        [self commonInit];
    }
    
    return self;
}

// Called when loaded from storyboard
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self)
    {
        [self commonInit];
    }
    
    return self;
}

// Called when loaded from nib
- (instancetype)initWithNibName:(NSString *)nibNameOrNil
                         bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil
                           bundle:nibBundleOrNil];
    
    if (self)
    {
        [self commonInit];
    }
    
    return self;
}

- (void)commonInit
{
    _renderer = [[MetalRenderer alloc] init];
    
    // Register notifications to start/stop drawing as this app moves into the background
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    [notificationCenter addObserver: self
                           selector: @selector(didEnterBackground:)
                               name: UIApplicationDidEnterBackgroundNotification
                             object: nil];
    
    [notificationCenter addObserver: self
                           selector: @selector(willEnterForeground:)
                               name: UIApplicationWillEnterForegroundNotification
                             object: nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopRenderLoop];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _metalView = (MetalView *)self.view;
    _metalView.clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0);
    
    // Load all renderer assets before starting the render loop
    [_renderer configure:_metalView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Start the render loop
    [self dispatchRenderLoop];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Stop the render loop
    [self stopRenderLoop];
}

#pragma mark - Render Loop

- (void)dispatchRenderLoop
{
    // Set up the render loop to redraw in sync with the main screen refresh rate
    // Create a render loop timer using a display link
    _displayLink = [[UIScreen mainScreen] displayLinkWithTarget:self
                                                       selector:@selector(renderLoop)];
    _displayLink.frameInterval = 1; // display link will fire for every display frame
    
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                       forMode:NSDefaultRunLoopMode];
}

- (void)stopRenderLoop
{
    if (_displayLink)
    {
        [_displayLink invalidate];
        _displayLink = nil;
    }
}

- (void)renderLoop
{
    // Display (render)
    
    // Call the display method directly on the render view
    [_metalView display];
}

- (BOOL)isPaused
{
    return _renderLoopPaused;
}

- (void)setPaused:(BOOL)paused
{
    if (paused != _renderLoopPaused)
    {
        if (_displayLink)
        {
            // Inform the renderer we are about to pause/resume
            [_renderer viewController:self willPause:paused];
            
            _displayLink.paused = paused;
        }
        
        _renderLoopPaused = paused;
    }
}

#pragma mark - App States

- (void)didEnterBackground:(NSNotification *)notification
{
    [self setPaused:YES];
}

- (void)willEnterForeground:(NSNotification *)notification
{
    [self setPaused:NO];
}

@end
