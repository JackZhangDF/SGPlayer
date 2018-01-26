//
//  SGGLView.m
//  SGPlayer
//
//  Created by Single on 2018/1/24.
//  Copyright © 2018年 single. All rights reserved.
//

#import "SGGLView.h"

@interface SGGLView ()

{
    GLuint _displayFramebuffer;
    GLuint _displayRenderbuffer;
}

@property (nonatomic, assign) SGGLSize displaySize;
@property (nonatomic, strong) dispatch_queue_t drawingQueue;

@end

@implementation SGGLView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.drawingQueue = dispatch_queue_create("SGGLView-Drawing-Queue", DISPATCH_QUEUE_SERIAL);
        dispatch_sync(self.drawingQueue, ^{
            self.context = SGPLFGLContextAllocInit();
            SGPLGLContextSetCurrentContext(self.context);
            glClearColor(0, 0, 0, 1);
        });
    }
    return self;
}

- (void)dealloc
{
    dispatch_sync(self.drawingQueue, ^{
        [self destroyFramebuffer];
    });
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    int width = CGRectGetWidth(self.bounds);
    int height = CGRectGetHeight(self.bounds);
    if (width != _displaySize.width || height != _displaySize.width)
    {
        SGGLSize displaySize = {width, height};
        _displaySize = displaySize;
        dispatch_sync(self.drawingQueue, ^{
            [self destroyFramebuffer];
            [self setupFramebuffer];
        });
        [self display];
    }
}

- (void)display
{
    dispatch_async(self.drawingQueue, ^{
        SGPLGLContextSetCurrentContext(self.context);
        glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
        BOOL success = [self.delegate glView:self draw:self.displaySize];
        if (success)
        {
            glBindRenderbuffer(GL_RENDERBUFFER, _displayRenderbuffer);
            [self present];
        }
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glBindRenderbuffer(GL_RENDERBUFFER, 0);
    });
}

- (void)clear
{
    dispatch_async(self.drawingQueue, ^{
        SGPLGLContextSetCurrentContext(self.context);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        [self present];
    });
}

- (void)setupFramebuffer
{
    if (_displaySize.width == 0 || _displaySize.height == 0)
    {
        return;
    }
    SGPLGLContextSetCurrentContext(self.context);
    glGenFramebuffers(1, &_displayFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
    glGenRenderbuffers(1, &_displayRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _displayRenderbuffer);
    [self renderbufferStorage];
    glViewport(0, 0, (GLint)_displaySize.width, (GLint)_displaySize.height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _displayRenderbuffer);
}

- (void)destroyFramebuffer
{
    SGPLGLContextSetCurrentContext(self.context);
    if (_displayFramebuffer)
    {
        glDeleteFramebuffers(1, &_displayFramebuffer);
        _displayFramebuffer = 0;
    }
    if (_displayRenderbuffer)
    {
        glDeleteRenderbuffers(1, &_displayRenderbuffer);
        _displayRenderbuffer = 0;
    }
}

@end