/*
 *  $Id$
 *
 *  Copyright (C) 2005, 2006 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "PreferencesController.h"

#import "MissingResourceException.h"
#import "UtilityFunctions.h"

static PreferencesController	*sharedPreferences			= nil;

NSString *GeneralPreferencesToolbarItemIdentifier	= @"org.sbooth.Max.Preferences.General";
NSString *FormatsPreferencesToolbarItemIdentifier	= @"org.sbooth.Max.Preferences.Formats";
NSString *OutputPreferencesToolbarItemIdentifier	= @"org.sbooth.Max.Preferences.Output";
NSString *TaggingPreferencesToolbarItemIdentifier	= @"org.sbooth.Max.Preferences.Tagging";
NSString *FreeDBPreferencesToolbarItemIdentifier	= @"org.sbooth.Max.Preferences.FreeDB";
NSString *RipperPreferencesToolbarItemIdentifier	= @"org.sbooth.Max.Preferences.Ripper";
NSString *AlbumArtPreferencesToolbarItemIdentifier	= @"org.sbooth.Max.Preferences.AlbumArt";

@interface PreferencesController (Private)
- (void) selectPreferencePaneUsingToolbar:(id)sender;
@end

@implementation PreferencesController

// Set up initial defaults
+ (void) initialize
{
	NSString				*defaultsPath;
    NSMutableDictionary		*defaultsDictionary;
    NSDictionary			*initialValuesDictionary;
	NSArray					*defaultFiles;
	unsigned				i;

	@try {
		defaultsDictionary	= [NSMutableDictionary dictionaryWithCapacity:20];
		defaultFiles		= [NSArray arrayWithObjects:@"ApplicationControllerDefaults", @"MediaControllerDefaults", @"FreeDBDefaults",
			@"CompactDiscDocumentDefaults", @"ComparisonRipperDefaults", @"ParanoiaDefaults", @"TrackDefaults", 
			@"AlbumArtDefaults", @"PCMGeneratingTaskDefaults", @"ConverterTaskDefaults", @"EncoderTaskDefaults", nil];
		// Add the default values as resettable
		for(i = 0; i < [defaultFiles count]; ++i) {
			defaultsPath = [[NSBundle mainBundle] pathForResource:[defaultFiles objectAtIndex:i] ofType:@"plist"];
			if(nil == defaultsPath) {
				@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
															userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%@.plist", [defaultFiles objectAtIndex:i]] forKey:@"filename"]];
			}
			[defaultsDictionary addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:defaultsPath]];
		}
	    
		initialValuesDictionary = [defaultsDictionary dictionaryWithValuesForKeys:[defaultsDictionary allKeys]];		
		[[NSUserDefaults standardUserDefaults] registerDefaults:initialValuesDictionary];
		[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:initialValuesDictionary];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"PreferencesController"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

+ (PreferencesController *) sharedPreferences
{
	@synchronized(self) {
		if(nil == sharedPreferences) {
			sharedPreferences = [[self alloc] init];
		}
	}
	return sharedPreferences;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedPreferences) {
            return [super allocWithZone:zone];
        }
    }
    return sharedPreferences;
}

- (id) init
{
	if((self = [super initWithWindowNibName:@"Preferences"])) {
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[super dealloc];
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (unsigned)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void)		release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

- (void) awakeFromNib
{
    NSToolbar		*toolbar;
	
    toolbar = [[[NSToolbar alloc] initWithIdentifier:@"org.sbooth.Max.Preferences.ToolbarIdentifier"] autorelease];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    
    [toolbar setDelegate:self];
	
    [[self window] setToolbar:toolbar];
}

- (void) windowDidLoad
{
	NSToolbar *toolbar = [[self window] toolbar];
	
	if(nil != [toolbar visibleItems] && 0 != [[toolbar visibleItems] count]) {
		[toolbar setSelectedItemIdentifier:[[[toolbar visibleItems] objectAtIndex:0] itemIdentifier]];
	}
	else if(nil != [toolbar items] && 0 != [[toolbar items] count]) {
		[toolbar setSelectedItemIdentifier:[[[toolbar items] objectAtIndex:0] itemIdentifier]];
	}
	else {
		[toolbar setSelectedItemIdentifier:GeneralPreferencesToolbarItemIdentifier];
	}
	[self selectPreferencePaneUsingToolbar:self];
	
	[self setShouldCascadeWindows:NO];
	[[self window] center];
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag 
{
    NSToolbarItem	*toolbarItem				= nil;

    if([itemIdentifier isEqualToString:GeneralPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"General", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"General", @"Preferences", @"")];		
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Control the general behavior of Max", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"GeneralToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPreferencePaneUsingToolbar:)];
	}
    else if([itemIdentifier isEqualToString:FormatsPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Formats", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Formats", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Select the encoders that Max will use to produce audio", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"FormatsToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPreferencePaneUsingToolbar:)];
	}
    else if([itemIdentifier isEqualToString:OutputPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Output", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Output", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Select where output files will be saved and how they will be named", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"OutputToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPreferencePaneUsingToolbar:)];
	}
    else if([itemIdentifier isEqualToString:TaggingPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Tagging", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Tagging", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Specify custom tag names for FLAC, Ogg Vorbis and Monkey's Audio files", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"TaggingToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPreferencePaneUsingToolbar:)];
	}
    else if([itemIdentifier isEqualToString:FreeDBPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"FreeDB", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"FreeDB", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Specify the protocol and server used by FreeDB to retrieve disc information", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"FreeDBToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPreferencePaneUsingToolbar:)];
	}
    else if([itemIdentifier isEqualToString:RipperPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Ripper", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Ripper", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Adjust the parameters used for digital audio extraction", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"RipperToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPreferencePaneUsingToolbar:)];
	}
    else if([itemIdentifier isEqualToString:AlbumArtPreferencesToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Album Art", @"Preferences", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Album Art", @"Preferences", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Specify whether to save album art with the encoded files", @"Preferences", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"AlbumArtToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(selectPreferencePaneUsingToolbar:)];
	}
	else {
		toolbarItem = nil;
    }
	
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
	return [NSArray arrayWithObjects:
		GeneralPreferencesToolbarItemIdentifier,
		FormatsPreferencesToolbarItemIdentifier,
		OutputPreferencesToolbarItemIdentifier,
		RipperPreferencesToolbarItemIdentifier,
		FreeDBPreferencesToolbarItemIdentifier,
		TaggingPreferencesToolbarItemIdentifier,
		AlbumArtPreferencesToolbarItemIdentifier,
		nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar 
{
	return [NSArray arrayWithObjects:
		GeneralPreferencesToolbarItemIdentifier,
		FormatsPreferencesToolbarItemIdentifier,
		OutputPreferencesToolbarItemIdentifier,
		RipperPreferencesToolbarItemIdentifier,
		FreeDBPreferencesToolbarItemIdentifier,
		TaggingPreferencesToolbarItemIdentifier,
		AlbumArtPreferencesToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		nil];
}

- (NSArray *) toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:
		GeneralPreferencesToolbarItemIdentifier,
		FormatsPreferencesToolbarItemIdentifier,
		OutputPreferencesToolbarItemIdentifier,
		RipperPreferencesToolbarItemIdentifier,
		FreeDBPreferencesToolbarItemIdentifier,
		TaggingPreferencesToolbarItemIdentifier,
		AlbumArtPreferencesToolbarItemIdentifier,
		nil];
}

- (void) selectPreferencePaneUsingToolbar:(id)sender
{
	[self selectPreferencePane:[[[self window] toolbar] selectedItemIdentifier]];
}

- (void) selectPreferencePane:(NSString *)itemIdentifier
{
	NSToolbar				*toolbar;
	Class					prefPaneClass;
	NSWindowController		*prefPaneObject;
	NSView					*prefView, *oldContentView;
	float					toolbarHeight, windowHeight, newWindowHeight, newWindowWidth;
	NSRect					windowFrame, newFrameRect, newWindowFrame;
	NSWindow				*myWindow;
	
	myWindow				= [self window];
	oldContentView			= [myWindow contentView];
	toolbar					= [myWindow toolbar];
	prefPaneClass			= NSClassFromString([[[itemIdentifier componentsSeparatedByString:@"."] lastObject] stringByAppendingString:@"PreferencesController"]);
	prefPaneObject			= [[prefPaneClass alloc] init];
	prefView				= [[prefPaneObject window] contentView];
	windowHeight			= NSHeight([[myWindow contentView] frame]);
	
	
	// Select the appropriate toolbar item if it isn't already
	if(NO == [[[[self window] toolbar] selectedItemIdentifier] isEqualToString:itemIdentifier]) {
		[[[self window] toolbar] setSelectedItemIdentifier:itemIdentifier];
	}

	// Calculate toolbar height
	if([toolbar isVisible]) {
		windowFrame = [NSWindow contentRectForFrameRect:[myWindow frame] styleMask:[myWindow styleMask]];
		toolbarHeight = NSHeight(windowFrame) - windowHeight;
	}
	
	newWindowHeight		= NSHeight([prefView frame]) + toolbarHeight;
	newWindowWidth		= NSWidth([[myWindow contentView] frame]); // Don't adjust width, only height
	newFrameRect		= NSMakeRect(NSMinX(windowFrame), NSMaxY(windowFrame) - newWindowHeight, newWindowWidth, newWindowHeight);
	newWindowFrame		= [NSWindow frameRectForContentRect:newFrameRect styleMask:[myWindow styleMask]];
	
	[myWindow setContentView:[[[NSView alloc] init] autorelease]];
	[myWindow setTitle:[[self toolbar:toolbar itemForItemIdentifier:itemIdentifier willBeInsertedIntoToolbar:NO] label]];
	[myWindow setFrame:newWindowFrame display:YES animate:[myWindow isVisible]];
	[myWindow setContentView:[prefView retain]];
	
	// Why does this cause a crash?
	//[prefPaneObject release];
	//[oldContentView release];
}

@end
