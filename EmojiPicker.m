#import <Cocoa/Cocoa.h>

@interface EmojiPickerDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *_window;
    NSMatrix *_matrix;
    NSTextField *_status;
}
@end

static NSString *StringForCodePoint(unsigned long codePoint) {
    UniChar characters[2];
    if (codePoint <= 0xffffUL) {
        characters[0] = (UniChar)codePoint;
        return [NSString stringWithCharacters:characters length:1];
    }
    codePoint -= 0x10000UL;
    characters[0] = (UniChar)(0xd800UL + (codePoint >> 10));
    characters[1] = (UniChar)(0xdc00UL + (codePoint & 0x3ffUL));
    return [NSString stringWithCharacters:characters length:2];
}

@implementation EmojiPickerDelegate

- (NSArray *)loadEmoji {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"emoji26-additions"
                                                    ofType:@"txt"];
    NSString *text = [NSString stringWithContentsOfFile:path
                                              encoding:NSUTF8StringEncoding
                                                 error:NULL];
    NSMutableArray *result = [NSMutableArray array];
    NSArray *lines = [text componentsSeparatedByCharactersInSet:
                      [NSCharacterSet newlineCharacterSet]];
    NSEnumerator *enumerator = [lines objectEnumerator];
    NSString *line;
    while ((line = [enumerator nextObject])) {
        unsigned int codePoint = 0;
        if (sscanf([line UTF8String], "U+%x", &codePoint) == 1)
            [result addObject:StringForCodePoint(codePoint)];
    }
    return result;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSArray *emoji = [self loadEmoji];
    NSInteger columns = 10;
    NSInteger rows = ([emoji count] + columns - 1) / columns;
    NSRect frame = NSMakeRect(0, 0, 620, 520);
    NSFont *emojiFont = [NSFont fontWithName:@"Emoji26 Additions" size:30.0];
    NSButtonCell *prototype;
    NSScrollView *scroll;
    NSView *content;
    NSInteger index;

    (void)notification;
    _window = [[NSWindow alloc] initWithContentRect:frame
                                          styleMask:(NSTitledWindowMask |
                                                     NSClosableWindowMask |
                                                     NSMiniaturizableWindowMask |
                                                     NSResizableWindowMask)
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    [_window setTitle:@"Emoji 26 Additions"];
    [_window setMinSize:NSMakeSize(360, 300)];
    [_window setReleasedWhenClosed:NO];

    content = [_window contentView];
    _status = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 10, 590, 24)];
    [_status setEditable:NO];
    [_status setSelectable:NO];
    [_status setBordered:NO];
    [_status setDrawsBackground:NO];
    [_status setStringValue:@"Click an emoji to copy it to the clipboard."];
    [_status setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
    [content addSubview:_status];

    scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 42, 600, 468)];
    [scroll setHasVerticalScroller:YES];
    [scroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    prototype = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
    [prototype setButtonType:NSMomentaryPushInButton];
    [prototype setBezelStyle:NSRegularSquareBezelStyle];
    [prototype setFont:emojiFont ? emojiFont : [NSFont systemFontOfSize:24]];
    _matrix = [[NSMatrix alloc] initWithFrame:NSMakeRect(0, 0, columns * 54, rows * 54)
                                         mode:NSRadioModeMatrix
                                    prototype:prototype
                                 numberOfRows:rows
                              numberOfColumns:columns];
    [_matrix setCellSize:NSMakeSize(50, 50)];
    [_matrix setIntercellSpacing:NSMakeSize(4, 4)];
    [_matrix setTarget:self];
    [_matrix setAction:@selector(copySelectedEmoji:)];
    for (index = 0; index < rows * columns; index++) {
        NSCell *cell = [_matrix cellAtRow:index / columns column:index % columns];
        if (index < (NSInteger)[emoji count]) {
            [cell setTitle:[emoji objectAtIndex:index]];
            [cell setTag:index];
        } else {
            [cell setEnabled:NO];
        }
    }
    [scroll setDocumentView:_matrix];
    [content addSubview:scroll];
    [scroll release];

    [_window center];
    [_window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)copySelectedEmoji:(id)sender {
    NSCell *cell = [sender selectedCell];
    NSString *emoji = [cell title];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType]
                       owner:nil];
    [pasteboard setString:emoji forType:NSStringPboardType];
    [_status setStringValue:[NSString stringWithFormat:@"%@ copied.", emoji]];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (void)dealloc {
    [_status release];
    [_matrix release];
    [_window release];
    [super dealloc];
}

@end

int main(int argc, const char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSApplication *application = [NSApplication sharedApplication];
    EmojiPickerDelegate *delegate = [[[EmojiPickerDelegate alloc] init] autorelease];
    (void)argc;
    (void)argv;
    [application setActivationPolicy:NSApplicationActivationPolicyRegular];
    [application setDelegate:delegate];
    [application run];
    [pool drain];
    return 0;
}
