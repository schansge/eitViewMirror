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
@property (nonatomic, assign, getter = isUpdating) BOOL updating;
@property (nonatomic, assign) CGPoint oldTouchPoint;
@property (nonatomic, assign) GLfloat xAxisRotation;
@property (nonatomic, assign) GLfloat zAxisRotation;

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
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.analysisPopoverController = [[UIPopoverController alloc] initWithContentViewController:self.analysisViewController];
    }
    
    // initialize open gl
    [EAGLContext setCurrentContext:self.context];
    self.baseEffect = [[GLKBaseEffect alloc] init];
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glEnable(GL_DEPTH_TEST);
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // init properties
    self.updating = NO;
}

-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    // prevent pausing of event loop when showing analysis view on iPhone
    if (self.analysisViewController.view.window) {
        self.paused = NO;
    }
}

- (IBAction)infoButtonPressed:(id)sender {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.analysisPopoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
    else {
        [self.navigationController pushViewController:self.analysisViewController animated:YES];
    }
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
    self.baseEffect.transform.modelviewMatrix = modelViewMatrix;
    
    [self.baseEffect prepareToDraw];
}

-(void)updateData {
    // error handler for returning to connect screen on error
    void (^errorHandler)(NSError* error) = ^(NSError* error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController popViewControllerAnimated:YES];
        });
    };
    
    // update renderer
    for (id<ESTRenderer> renderer in self.renderer) {
        [renderer updateWithMirrorClient:self.mirrorClient failure:errorHandler];
    }
    
    // update analysis view
    if (self.analysisViewController.view.window) {
        if (!self.isUpdating) {
            [self.mirrorClient request:ESTMirrorClientRequestAnalysisUpdate withSuccess:^(NSData* analysisData) {
                NSDictionary* analysis = [NSJSONSerialization JSONObjectWithData:analysisData options:kNilOptions error:nil];
                [self.analysisViewController updateAnalysis:analysis[@"analysis"]];
                
                self.updating = NO;
            } failure:nil];
        }
    }
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

#pragma mark - Touch Events

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    // save start touch point
    self.oldTouchPoint = [touches.allObjects[0] locationInView:self.view];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    // change rotation angles according to finger position relative to last touch event event
    CGPoint newTouchPoint = [touches.allObjects[0] locationInView:self.view];
    
    self.xAxisRotation += 2e-1 * (newTouchPoint.y - self.oldTouchPoint.y);
    if (fabsf(fmodf(self.xAxisRotation, 360.0)) < 90.0 || fabsf(fmodf(self.xAxisRotation, 360.0)) >= 270.0) {
        if (newTouchPoint.y < self.view.bounds.size.height / 2) {
            self.zAxisRotation -= 2e-1 * (newTouchPoint.x - self.oldTouchPoint.x);
        }
        else {
            self.zAxisRotation += 2e-1 * (newTouchPoint.x - self.oldTouchPoint.x);
        }
    }
    else {
        if (newTouchPoint.y < self.view.bounds.size.height / 2) {
            self.zAxisRotation += 2e-1 * (newTouchPoint.x - self.oldTouchPoint.x);
        }
        else {
            self.zAxisRotation -= 2e-1 * (newTouchPoint.x - self.oldTouchPoint.x);
        }
    }
    
    self.oldTouchPoint = newTouchPoint;
}

@end
