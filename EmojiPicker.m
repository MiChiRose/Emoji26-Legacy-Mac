#import <Cocoa/Cocoa.h>
int main(int argc, const char *argv[]) { NSAutoreleasePool *p=[[NSAutoreleasePool alloc] init];
  NSApplication *a=[NSApplication sharedApplication]; NSArray *items=@[@"🫨",@"👍🏽",@"🇺🇦",@"👨‍👩‍👧",@"👩‍⚕️",@"❤️"];
  NSAlert *alert=[[[NSAlert alloc] init] autorelease]; [alert setMessageText:@"Emoji Legacy Picker"]; [alert setInformativeText:@"Choose an emoji; it is copied to the pasteboard."];
  for(NSString *s in items) [alert addButtonWithTitle:s]; NSInteger choice=[alert runModal]-NSAlertFirstButtonReturn;
  if(choice>=0 && choice<(NSInteger)[items count]) { NSPasteboard *pb=[NSPasteboard generalPasteboard]; [pb clearContents]; [pb setString:[items objectAtIndex:choice] forType:NSStringPboardType]; }
  [p drain]; return 0; }
