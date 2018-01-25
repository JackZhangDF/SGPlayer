//
//  SGFFVideoOutput.m
//  SGPlayer
//
//  Created by Single on 2018/1/22.
//  Copyright © 2018年 single. All rights reserved.
//

#import "SGFFVideoOutput.h"
#import "SGFFVideoOutputRender.h"
#import "SGGLDisplayLink.h"
#import "SGGLView.h"
#import "SGPlayerMacro.h"
#import "SGGLViewport.h"
#import "SGGLYUV420Program.h"
#import "SGGLPlaneModel.h"
#import "SGGLTextureYUV420.h"
#import "SGPlatform.h"

@interface SGFFVideoOutput () <SGGLViewDelegate>

@property (nonatomic, strong) NSLock * coreLock;
@property (nonatomic, strong) SGGLDisplayLink * displayLink;
@property (nonatomic, strong) SGGLView * glView;
@property (nonatomic, strong) SGGLYUV420Program * program;
@property (nonatomic, strong) SGGLPlaneModel * model;
@property (nonatomic, strong) SGGLTextureYUV420 * texture;
@property (nonatomic, strong) SGFFVideoOutputRender * currentRender;

@end

@implementation SGFFVideoOutput

- (id <SGFFOutputRender>)renderWithFrame:(id <SGFFFrame>)frame
{
    SGFFVideoOutputRender * render = [[SGFFObjectPool sharePool] objectWithClass:[SGFFVideoOutputRender class]];
    [render updateVideoFrame:frame.videoFrame];
    return render;
}

- (instancetype)init
{
    if (self = [super init])
    {
        self.coreLock = [[NSLock alloc] init];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.glView = [[SGGLView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
            self.glView.delegate = self;
            [self.delegate videoOutputDidChangeDisplayView:self];
            SGWeakSelf
            self.displayLink = [SGGLDisplayLink displayLinkWithCallback:^{
                SGStrongSelf
                [strongSelf displayLinkHandler];
            }];
        });
    }
    return self;
}

- (void)dealloc
{
    [self.displayLink invalidate];
    [self clearCurrentRender];
}

- (SGPLFView *)displayView
{
    return self.glView;
}

- (void)displayLinkHandler
{
    SGFFVideoOutputRender * render = [self.renderSource outputFecthRender:self];
    if (render)
    {
        [self clearCurrentRender];
        self.currentRender = render;
        [self.glView display];
    }
}

- (void)setupOpenGLIfNeed
{
    if (!self.texture) {
        self.texture = [[SGGLTextureYUV420 alloc] init];
    }
    if (!self.program) {
        self.program = [[SGGLYUV420Program alloc] init];
    }
    if (!self.model) {
        self.model = [[SGGLPlaneModel alloc] init];
    }
}

- (void)clearCurrentRender
{
    if (self.currentRender)
    {
        [self.coreLock lock];
        [self.currentRender unlock];
        self.currentRender = nil;
        [self.coreLock unlock];
    }
}


#pragma mark - SGGLViewDelegate

- (void)glView:(SGGLView *)glView draw:(SGGLSize)size
{
    [self.coreLock lock];
    SGFFVideoOutputRender * render = self.currentRender;
    if (!render)
    {
        [self.coreLock unlock];
        return;
    }
    [render lock];
    [self.coreLock unlock];
    [self setupOpenGLIfNeed];
    [self.program use];
    [self.program bindVariable];
    [self.texture updateTexture:render];
    [self.model bindPosition_location:self.program.position_location
           textureCoordinate_location:self.program.textureCoordinate_location];
    [self.program updateModelViewProjectionMatrix:GLKMatrix4Identity];
    SGGLSize renderSize = {render.videoFrame.width, render.videoFrame.height};
    [SGGLViewport updateViewport:renderSize
                     displaySize:size
                            mode:SGGLViewportModeResizeAspect];
    [self.model draw];
    [self.model bindEmpty];
    [render unlock];
}

@end
