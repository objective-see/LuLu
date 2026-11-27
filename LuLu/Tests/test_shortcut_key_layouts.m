//
//  test_shortcut_key_layouts.m
//  LuLu
//
//  Regression tests for macOS Command shortcut layout handling
//

#import <Foundation/Foundation.h>

static int testCount = 0;
static int failureCount = 0;

static NSString* shortcutCharactersForEventStrings(NSString* characters, NSString* charactersIgnoringModifiers, BOOL commandDown)
{
    if( (YES == commandDown) &&
        (0 != characters.length) )
    {
        return characters;
    }

    if(0 != charactersIgnoringModifiers.length)
    {
        return charactersIgnoringModifiers;
    }

    return characters;
}

static void checkShortcut(const char* name, NSString* characters, NSString* charactersIgnoringModifiers, BOOL commandDown, NSString* expected)
{
    testCount++;

    NSString* result = shortcutCharactersForEventStrings(characters, charactersIgnoringModifiers, commandDown);

    if(YES != [result isEqualToString:expected])
    {
        failureCount++;
        fprintf(stderr, "FAIL %s: got '%s', expected '%s'\n", name, result.UTF8String, expected.UTF8String);
    }
}

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        // Dvorak - QWERTY ⌘ regression: Command + physical W should be Cmd+W.
        // On this layout, characters reflects the Command/QWERTY layer ("w"),
        // while charactersIgnoringModifiers strips Command and reports the
        // non-Command Dvorak character (",").
        checkShortcut("dvorak-qwerty-cmd-physical-w", @"w", @",", YES, @"w");

        // Companion regression: Command + physical comma should stay Cmd+, and
        // must not be misread as Cmd+W.
        checkShortcut("dvorak-qwerty-cmd-physical-comma", @",", @"w", YES, @",");

        // Plain Dvorak/no Command-layer translation should remain layout based.
        checkShortcut("plain-dvorak-physical-w", @",", @",", NO, @",");

        // Preserve fallback behavior for events that do not provide characters.
        checkShortcut("fallback-characters-ignoring-modifiers", @"", @"c", YES, @"c");

        if(0 != failureCount)
        {
            fprintf(stderr, "%d/%d shortcut layout tests failed\n", failureCount, testCount);
            return 1;
        }

        fprintf(stdout, "%d shortcut layout tests passed\n", testCount);
        return 0;
    }
}
