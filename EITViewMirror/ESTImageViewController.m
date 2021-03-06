//
//  ESTViewController.m
//  EITViewMirror
//
//  Created by Patrik Gebhardt on 05/02/14.
//  Copyright (c) 2014 EST. All rights reserved.
//

#import "ESTImageViewController.h"
#import "ESTAnalysisViewController.h"
#import "ESTRenderer.h"

@interface ESTImageViewController ()

@property (nonatomic, strong) ESTAnalysisViewController* analysisViewController;
@property (nonatomic, strong) UIPopoverController* analysisPopoverController;
@property (nonatomic, strong) GLKBaseEffect* baseEffect;
@property (nonatomic, assign) GLfloat xAxisRotation;
@property (nonatomic, assign) GLfloat zAxisRotation;
@property (nonatomic, assign) GLfloat zoomFactor;
@property (nonatomic, assign) GLfloat oldZoomFactor;

@end

@implementation ESTImageViewController

-(void)viewDidLoad {
    [super viewDidLoad];
    
    // init gl context and assign it to main view
    GLKView* view = (GLKView*)self.view;
    view.context = self.context;
    view.drawableMultisample = GLKViewDrawableMultisample4X;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    // init properties
    self.analysisViewController = [[ESTAnalysisViewController alloc] initWithStyle:UITableViewStylePlain];
    self.analysisPopoverController = [[UIPopoverController alloc] initWithContentViewController:self.analysisViewController];
    self.zoomFactor = self.oldZoomFactor = 1.0;
    
    // init gesture recognizer for rotation and zooming
    UIPinchGestureRecognizer* pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(updateZoomFactor:)];
    pinchGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:pinchGestureRecognizer];
    
    ESTRotateGestureRecognizer* rotateGestureRecognizer = [[ESTRotateGestureRecognizer alloc] initWithTarget:self action:@selector(updateViewRotation:)];
    rotateGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:rotateGestureRecognizer];
    
    // initialize open gl
    [EAGLContext setCurrentContext:self.context];
    self.baseEffect = [[GLKBaseEffect alloc] init];
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glEnable(GL_DEPTH_TEST);
}

- (IBAction)infoButtonPressed:(id)sender {
    [self.analysisPopoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (IBAction)calibrateButtonPressed:(id)sender {
    [self.mirrorClient request:ESTMirrorClientRequestCalibration];
}

-(void)updateBaseEffect {
    // set projection matrix
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(10.0), aspect, 0.1, 100.0);
    self.baseEffect.transform.projectionMatrix = projectionMatrix;
    
    // set model view matrix
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0, 0.0, -20.0);
    if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
        modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, aspect, aspect, aspect);
    }
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, GLKMathDegreesToRadians(self.xAxisRotation), 1.0, 0.0, 0.0);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, GLKMathDegreesToRadians(self.zAxisRotation), 0.0, 0.0, 1.0);
    modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, self.zoomFactor, self.zoomFactor, self.zoomFactor);
    self.baseEffect.transform.modelviewMatrix = modelViewMatrix;
    
    [self.baseEffect prepareToDraw];
}

-(void)updateData {
    // error handler for returning to connect screen on error
    void (^errorHandler)(NSError*) = ^(NSError* error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController popViewControllerAnimated:YES];
        });
    };
    
    // update renderer
    for (id<ESTRenderer> renderer in self.renderer) {
        [renderer updateWithMirrorClient:self.mirrorClient failure:errorHandler];
    }
    
    // update analysis view
    if (self.analysisPopoverController.isPopoverVisible) {
        [self.analysisViewController updateWithMirrorClient:self.mirrorClient failure:errorHandler];
    }
}

-(void)updateViewRotation:(ESTRotateGestureRecognizer *)gestureRecognizer {
    self.xAxisRotation += gestureRecognizer.xAxisRotation;
    if (fabsf(fmodf(self.xAxisRotation, 360.0)) < 90.0 || fabsf(fmodf(self.xAxisRotation, 360.0)) >= 270.0) {
        self.zAxisRotation += gestureRecognizer.zAxisRotation;
    }
    else {
        self.zAxisRotation -= gestureRecognizer.zAxisRotation;
    }
}

-(void)updateZoomFactor:(UIPinchGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        self.oldZoomFactor = self.zoomFactor;
    }
    self.zoomFactor = self.oldZoomFactor * gestureRecognizer.scale;
}

#pragma mark - UIGesturRecognizerDelegate

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // Prevent gesture recognizer on connect button
    return ![touch.view isKindOfClass:[UIButton class]];
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

#pragma mark - GLKViewDelegate

-(void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // draw renderer
    for (id<ESTRenderer> renderer in self.renderer) {
        [renderer drawInRect:rect];
    }
}

#pragma mark - GLKViewController

-(void)update {
    [self updateBaseEffect];
    [self updateData];
}

@end
