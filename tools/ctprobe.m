#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>

static int glyphs(CTFontRef font, const UniChar *chars, CFIndex count) {
    CGGlyph out[32];
    return CTFontGetGlyphsForCharacters(font, chars, out, count) && out[0] != 0;
}
static int shapedOne(CTFontRef font, const UniChar *chars, CFIndex count) {
    CFStringRef s = CFStringCreateWithCharacters(kCFAllocatorDefault, chars, count);
    CFAttributedStringRef a = CFAttributedStringCreate(kCFAllocatorDefault, s,
        (CFDictionaryRef)[NSDictionary dictionaryWithObject:(id)font forKey:(id)kCTFontAttributeName]);
    CTLineRef line = CTLineCreateWithAttributedString(a); CFArrayRef runs = CTLineGetGlyphRuns(line);
    CFIndex n = 0, i; for (i = 0; i < CFArrayGetCount(runs); i++) n += CTRunGetGlyphCount((CTRunRef)CFArrayGetValueAtIndex(runs, i));
    CFRelease(line); CFRelease(a); CFRelease(s); return n == 1;
}
static void printFontIdentity(CTFontRef font) {
    CFStringRef family = CTFontCopyFamilyName(font);
    CFStringRef postscript = CTFontCopyPostScriptName(font);
    char familyBytes[256] = "";
    char postscriptBytes[256] = "";
    if (family) CFStringGetCString(family, familyBytes, sizeof(familyBytes), kCFStringEncodingUTF8);
    if (postscript) CFStringGetCString(postscript, postscriptBytes, sizeof(postscriptBytes), kCFStringEncodingUTF8);
    printf("resolved-family=%s postscript=%s glyphs=%ld\n",
           familyBytes, postscriptBytes, (long)CTFontGetGlyphCount(font));
    if (family) CFRelease(family);
    if (postscript) CFRelease(postscript);
}
int main(int argc, const char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (argc < 2 || argc > 4) { fprintf(stderr, "usage: ctprobe FONT [FAMILY] [--additive]\n"); return 64; }
    NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
    CFErrorRef error = NULL;
    if (!CTFontManagerRegisterFontsForURL((CFURLRef)url, kCTFontManagerScopeProcess, &error)) {
        fprintf(stderr, "CoreText registration failed\n"); if (error) CFRelease(error); return 1;
    }
    CFArrayRef descriptors = CTFontManagerCreateFontDescriptorsFromURL((CFURLRef)url);
    if (!descriptors || CFArrayGetCount(descriptors) == 0) {
        fprintf(stderr, "CoreText returned no font descriptors\n");
        if (descriptors) CFRelease(descriptors);
        return 1;
    }
    CTFontDescriptorRef desc = (CTFontDescriptorRef)CFRetain(CFArrayGetValueAtIndex(descriptors, 0));
    CFRelease(descriptors);
    CTFontRef font = CTFontCreateWithFontDescriptor(desc, 24, NULL);
    printFontIdentity(font);
    if (argc == 4 && strcmp(argv[3], "--additive") == 0) {
        const UniChar shaking[] = { 0xD83E, 0xDEE8 }; /* U+1FAE8 */
        const UniChar bags[] = { 0xD83E, 0xDEE9 };    /* U+1FAE9 */
        const UniChar mac26[] = { 0xD83E, 0xDE8A };   /* U+1FA8A */
        const UniChar legacy[] = { 0xD83D, 0xDE00 };  /* U+1F600 */
        int ok = glyphs(font, shaking, 2) && glyphs(font, bags, 2) &&
                 glyphs(font, mac26, 2) && !glyphs(font, legacy, 2);
        printf("U+1FAE8=%s U+1FAE9=%s U+1FA8A=%s legacy-U+1F600=%s\n",
          glyphs(font,shaking,2)?"ok":"missing",
          glyphs(font,bags,2)?"ok":"missing",
          glyphs(font,mac26,2)?"ok":"missing",
          glyphs(font,legacy,2)?"EXPOSED":"excluded");
        CFRelease(font); CFRelease(desc); [pool drain];
        return ok ? 0 : 2;
    }
    const UniChar single[] = { 0xD83E, 0xDEE8 }; /* U+1FAE8 */
    const UniChar skin[] = { 0xD83D, 0xDC4D, 0xD83C, 0xDFFD };
    const UniChar flag[] = { 0xD83C, 0xDDFA, 0xD83C, 0xDDE6 };
    const UniChar family[] = { 0xD83D,0xDC68,0x200D,0xD83D,0xDC69,0x200D,0xD83D,0xDC67 };
    const UniChar profession[] = { 0xD83D,0xDC69,0x200D,0x2695,0xFE0F };
    const UniChar variation[] = { 0x2764,0xFE0F };
    int ok = glyphs(font,single,2) && shapedOne(font,skin,4) && shapedOne(font,flag,4) && shapedOne(font,family,8) && shapedOne(font,profession,5) && shapedOne(font,variation,2);
    printf("single=%s skin=%s flag=%s family=%s profession=%s variation=%s\n",
      glyphs(font,single,2)?"ok":"missing", shapedOne(font,skin,4)?"one-glyph":"not-ligated", shapedOne(font,flag,4)?"one-glyph":"not-ligated", shapedOne(font,family,8)?"one-glyph":"not-ligated", shapedOne(font,profession,5)?"one-glyph":"not-ligated", shapedOne(font,variation,2)?"one-glyph":"not-ligated");
    CFRelease(font); CFRelease(desc); [pool drain];
    return ok ? 0 : 2;
}
