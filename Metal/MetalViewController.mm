//
//  MetalViewController.mm
//  Metal
//
//  Created by Andrei Marincas on 3/1/16.
//  Copyright © 2016 Andrei Marincas. All rights reserved.
//

#import "MetalViewController.h"
#import "MetalView.h"
#import "MetalRenderer.h"
#import "Scene.h"
#import "Cube.h"
#import "Transforms.h"

using namespace simd;
using namespace MTL;

@interface MetalViewController ()
{
    __weak MetalView    *_metalView;
    
    CADisplayLink       *_displayLink;
    
    // Boolean to determine if the first draw has occured
    BOOL                _firstDrawOccurred;
    
    // Time when last drawing occurred. Helps to keep track of the time interval between draws.
    CFTimeInterval      _renderTime;
    
    BOOL                _renderLoopPaused;
    
    MetalRenderer       *_renderer;
    
    Scene               *_scene;
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
    _metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
    // Load all renderer assets before starting the render loop
    [_renderer configure:_metalView];
    
    // Create the main scene
    id <MTLDevice> device = [_metalView device];
    _scene = [[Scene alloc] initWithName:@"MainScene" device:device];
    _renderer.scene = _scene;
    
    // Add node objects to the scene
    Cube *cube = [[Cube alloc] initWithName:@"Cube" device:device];
    cube.position.x += 5;
//    cube.scale.z = 0.5;
//    cube.scale = 0.5;
//    cube1.position.xyz = float3(1.0f);
//    cube1.scale = {2.0f, 1.5f, 1.0f};
//    [cube1 rotateBy:30 aroundAxis:zAxis];
//    [cube1 rotateBy:20 aroundAxis:yAxis];
//    [cube1 rotateBy:40 aroundAxis:xAxis];
    
//    Cube *cube2 = [[Cube alloc] initWithName:@"Cube2" device:device];
//    cube2.position = float3(-1.0f);
//    cube2.scale = float3(0.5f);
//    cube2.hidden = YES;
    
    Node *parent = [[Node alloc] initWithName:@"Parent" vertices:nil device:device];
    parent.position.z = 3;
//    parent.scale.x = 0.5;
//    parent.scale.z = 0.75;
//    parent.scale.z = 0.35;
//    parent.position.x += 1;
    Node *grandparent = [[Node alloc] initWithName:@"GrandParent" vertices:nil device:device];
//    grandparent.position.z = 3;
    [parent addChild:cube];
    [grandparent addChild:parent];
//    [_scene addChild:grandparent];
    
    [_scene addChild:grandparent];
//    [_scene addChild:cube2];
    
//    _scene.position.xz += 1;
//    _scene.scale = 2;
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
    
    if (!_firstDrawOccurred)
    {
        _timeSinceLastDraw = 0.0;
        _renderTime = CACurrentMediaTime();
        _firstDrawOccurred = YES;
    }
    else
    {
        CFTimeInterval currentTime = CACurrentMediaTime();
        _timeSinceLastDraw = currentTime - _renderTime;
        _renderTime = currentTime;
    }
    
    // Update renderer state before drawing
    [_renderer update:self];
    
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
