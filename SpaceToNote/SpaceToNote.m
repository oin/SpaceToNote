//
//  SpaceToNote.m
//  SpaceToNote
//
//  Created by Jonathan Aceituno on 06/10/2017.
//  Copyright © 2017 À la Bonne Sainte-Force. All rights reserved.
//

#import "SpaceToNote.h"
#import "JRSwizzle.h"
#import <Quartz/Quartz.h>

#pragma mark Tinderbox 7

@interface NSViewController (SpaceToNoteSwizzling)
-(void)stnswizzled_tbx_keyDown:(NSEvent *)event;
@end

@implementation NSViewController (SpaceToNoteSwizzling)
-(void)stnswizzled_tbx_keyDown:(NSEvent *)event
{
	if(![event isARepeat]) {
		BOOL spacePressed = [event keyCode] == 49;
		if(spacePressed) {
			if([self respondsToSelector:@selector(textWindow:)]) {
				[self performSelector:@selector(textWindow:) withObject:nil];
				return;
			}
		}
	}
	[self stnswizzled_tbx_keyDown:event];
}
@end

#pragma mark Curio

BOOL SpaceToNoteCurioShouldObserveChange = NO;
BOOL SpaceToNoteCurioDidObserveChange = NO;
CFAbsoluteTime SpaceToNoteCurioLastTimeQuickSpacebar = 0;
BOOL SpaceToNoteCurioSpaceWasPressed = NO;
CFAbsoluteTime SpaceToNoteCurioLastTimeSpaceWasPressed = 0;

BOOL SpaceToNoteCurioIsQuickLookVisible() {
	if([QLPreviewPanel sharedPreviewPanelExists]) {
		return [[QLPreviewPanel sharedPreviewPanel] isVisible];
	}
	return NO;
}

@interface NSView (SpaceToNoteSwizzling)
-(void)stnswizzled_curio_handleQuickSpacebarPressRelease;
-(void)stnswizzled_curio_didChange;
-(void)stnswizzled_curio_didChangeRect:(CGRect)rect;
-(void)stnswizzled_keyDown:(NSEvent *)event;
-(void)stnswizzled_keyUp:(NSEvent *)event;
@end

@implementation NSView (SpaceToNoteSwizzling)
-(void)stn_curio_showNotesWindow
{
	if([self respondsToSelector:@selector(projectController)]) {
		id projectController = [self performSelector:@selector(projectController)];
		id notesInspectorController = [projectController performSelector:@selector(notesInspectorController)];
		[notesInspectorController performSelector:@selector(showNotesWindow:) withObject:nil];
	}
}
-(void)stnswizzled_curio_handleQuickSpacebarPressRelease
{
	CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
	NSEventModifierFlags flags = [NSEvent modifierFlags];
	if((flags & NSEventModifierFlagControl) != 0 || ((flags & NSEventModifierFlagShift) != 0 && (flags & NSEventModifierFlagOption) != 0)) {
		// If we hit Ctrl+Space or Shift+Option+Space, then just show the notes window.
		[self stn_curio_showNotesWindow];
		SpaceToNoteCurioLastTimeQuickSpacebar = 0;
	} else {
		// Else, we should only show the notes window if nothing else has changed.
		SpaceToNoteCurioDidObserveChange = NO;
		SpaceToNoteCurioShouldObserveChange = YES;
		BOOL qlVisible = SpaceToNoteCurioIsQuickLookVisible();
		[self stnswizzled_curio_handleQuickSpacebarPressRelease];
		SpaceToNoteCurioDidObserveChange |= SpaceToNoteCurioIsQuickLookVisible() != qlVisible;
		SpaceToNoteCurioShouldObserveChange = NO;
		if(!SpaceToNoteCurioDidObserveChange || now - SpaceToNoteCurioLastTimeQuickSpacebar < 0.2) {
			[self stn_curio_showNotesWindow];
			SpaceToNoteCurioLastTimeQuickSpacebar = 0;
		}
	}
	SpaceToNoteCurioLastTimeQuickSpacebar = now;
}
-(void)stnswizzled_curio_didChange
{
	[self stnswizzled_curio_didChange];
	if(SpaceToNoteCurioShouldObserveChange) {
		SpaceToNoteCurioDidObserveChange = YES;
	}
}
-(void)stnswizzled_curio_didChangeRect:(CGRect)rect
{
	[self stnswizzled_curio_didChangeRect:rect];
	if(SpaceToNoteCurioShouldObserveChange) {
		SpaceToNoteCurioDidObserveChange = YES;
	}
}
-(void)stnswizzled_curio_keyDown:(NSEvent *)event
{
	if(![event isARepeat]) {
		SpaceToNoteCurioSpaceWasPressed = [event keyCode] == 49;
		if(SpaceToNoteCurioSpaceWasPressed) {
			SpaceToNoteCurioLastTimeSpaceWasPressed = CFAbsoluteTimeGetCurrent();
		} else {
			SpaceToNoteCurioLastTimeSpaceWasPressed = 0;
		}
	}
	[self stnswizzled_curio_keyDown:event];
}
-(void)stnswizzled_curio_keyUp:(NSEvent *)event
{
	BOOL spacePressed = [event keyCode] == 49;
	if(SpaceToNoteCurioSpaceWasPressed && spacePressed && CFAbsoluteTimeGetCurrent() - SpaceToNoteCurioLastTimeSpaceWasPressed < 0.3) {
		if([self respondsToSelector:@selector(singleSelectedAssetFigure)]) {
			id selectedAsset = [self performSelector:@selector(singleSelectedAssetFigure)];
			if(!selectedAsset) {
				[self stn_curio_showNotesWindow];
			}
		}
	}
	SpaceToNoteCurioSpaceWasPressed = NO;
	SpaceToNoteCurioLastTimeSpaceWasPressed = 0;
	[self stnswizzled_curio_keyUp:event];
}
@end

#pragma mark Plug-in management

@implementation SpaceToNote

+(instancetype)sharedInstance
{
	static SpaceToNote *plugin = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if(!plugin) {
			plugin = [[self alloc] init];
			Class ideaSpaceViewClass = NSClassFromString(@"IdeaSpaceView");
			if(ideaSpaceViewClass) {
				if([[[NSBundle bundleForClass:ideaSpaceViewClass] bundleIdentifier] isEqualToString:@"com.zengobi.curio"]) {
					NSLog(@"SpaceToNote loaded for Curio.");
					[ideaSpaceViewClass jr_swizzleMethod:@selector(handleQuickSpacebarPressRelease) withMethod:@selector(stnswizzled_curio_handleQuickSpacebarPressRelease) error:NULL];
					[ideaSpaceViewClass jr_swizzleMethod:@selector(didChange) withMethod:@selector(stnswizzled_curio_didChange) error:NULL];
					[ideaSpaceViewClass jr_swizzleMethod:@selector(didChangeRect:) withMethod:@selector(stnswizzled_curio_didChangeRect:) error:NULL];
					[ideaSpaceViewClass jr_swizzleMethod:@selector(keyDown:) withMethod:@selector(stnswizzled_curio_keyDown:) error:NULL];
					[ideaSpaceViewClass jr_swizzleMethod:@selector(keyUp:) withMethod:@selector(stnswizzled_curio_keyUp:) error:NULL];
				}
			} else {
				Class tbxMapViewControllerClass = NSClassFromString(@"TbxMapViewController");
				if(tbxMapViewControllerClass) {
					NSLog(@"SpaceToNote loaded for Tinderbox 7.");
					if([[[NSBundle bundleForClass:tbxMapViewControllerClass] bundleIdentifier] isEqualToString:@"com.eastgate.Tinderbox-7"]) {
						[tbxMapViewControllerClass jr_swizzleMethod:@selector(keyDown:) withMethod:@selector(stnswizzled_tbx_keyDown:) error:NULL];
					}
				}
			}
		}
	});
	return plugin;
}

+(void)load
{
	SpaceToNote *plugin = [self sharedInstance];
}

-(instancetype)init
{
	self = [super init];
	if(self) {
		
	}
	return self;
}

@end
