#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>

int main(int argc, const char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSURL *url;
    CFErrorRef error = NULL;
    CFArrayRef descriptors;
    CTFontDescriptorRef descriptor;
    CTFontRef font;
    UniChar characters[] = {
        0xD83E, 0xDEE8, 0x0020,
        0xD83E, 0xDEE9, 0x0020,
        0xD83E, 0xDE8A
    };
    CFStringRef text;
    CFAttributedStringRef attributed;
    CTLineRef line;
    NSBitmapImageRep *bitmap;
    NSGraphicsContext *graphics;
    CGContextRef context;
    NSData *png;
    BOOL wrote;

    if (argc != 3) {
        fprintf(stderr, "usage: renderprobe FONT OUTPUT.png\n");
        return 64;
    }
    url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
    if (!CTFontManagerRegisterFontsForURL((CFURLRef)url,
                                          kCTFontManagerScopeProcess,
                                          &error)) {
        fprintf(stderr, "CoreText registration failed\n");
        if (error) CFRelease(error);
        return 1;
    }
    descriptors = CTFontManagerCreateFontDescriptorsFromURL((CFURLRef)url);
    if (!descriptors || CFArrayGetCount(descriptors) == 0) {
        fprintf(stderr, "CoreText returned no descriptors\n");
        if (descriptors) CFRelease(descriptors);
        return 1;
    }
    descriptor = (CTFontDescriptorRef)CFRetain(CFArrayGetValueAtIndex(descriptors, 0));
    CFRelease(descriptors);
    font = CTFontCreateWithFontDescriptor(descriptor, 72, NULL);
    text = CFStringCreateWithCharacters(kCFAllocatorDefault,
                                        characters,
                                        sizeof(characters) / sizeof(characters[0]));
    attributed = CFAttributedStringCreate(
        kCFAllocatorDefault,
        text,
        (CFDictionaryRef)[NSDictionary dictionaryWithObject:(id)font
                                                     forKey:(id)kCTFontAttributeName]);
    line = CTLineCreateWithAttributedString(attributed);

    bitmap = [[[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:420
                      pixelsHigh:120
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSCalibratedRGBColorSpace
                    bytesPerRow:0
                   bitsPerPixel:0] autorelease];
    graphics = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:graphics];
    context = (CGContextRef)[graphics graphicsPort];
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 420, 120));
    CGContextSetTextPosition(context, 12, 24);
    CTLineDraw(line, context);
    [NSGraphicsContext restoreGraphicsState];

    png = [bitmap representationUsingType:NSPNGFileType
                                properties:[NSDictionary dictionary]];
    wrote = [png writeToFile:[NSString stringWithUTF8String:argv[2]]
                     options:NSDataWritingAtomic
                       error:NULL];

    CFRelease(line);
    CFRelease(attributed);
    CFRelease(text);
    CFRelease(font);
    CFRelease(descriptor);
    [pool drain];
    return wrote ? 0 : 74;
}
