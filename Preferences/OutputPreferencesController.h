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

#import <Cocoa/Cocoa.h>

enum {
	kCurrentDirectoryMenuItemTag		= 1,
	kChooseDirectoryMenuItemTag			= 2,
	kDefaultDirectoryMenuItemTag		= 3
};

@interface OutputPreferencesController : NSWindowController
{
    IBOutlet NSTextField		*_customNameTextField;
    IBOutlet NSPopUpButton		*_outputDirectoryPopUpButton;
    IBOutlet NSPopUpButton		*_temporaryDirectoryPopUpButton;
    NSString					*_customNameExample;
}

- (IBAction)	selectOutputDirectory:(id)sender;
- (IBAction)	selectTemporaryDirectory:(id)sender;

- (IBAction)	customNamingButtonAction:(id)sender;

@end
