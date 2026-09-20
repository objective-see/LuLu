//
//  test_wildcard_rules.m
//  LuLu
//
//  Test suite for wildcard rule paths
//
//  note: compiled against the real Shared/WildcardPath.m, so these exercise
//        the same code the app and extension use
//

#import <Foundation/Foundation.h>

#import "WildcardPath.h"

/* GLOBALS */

//counts
static int testsPassed = 0;
static int totalTests = 0;

//check a BOOL-returning call
static void checkBool(BOOL actual, BOOL expected, NSString* what)
{
    totalTests++;

    if(actual == expected)
    {
        testsPassed++;
        NSLog(@"✅ PASS: %@", what);
    }
    else
    {
        NSLog(@"❌ FAIL: %@ (got %@, expected %@)", what, actual ? @"YES" : @"NO", expected ? @"YES" : @"NO");
    }

    return;
}

//check a string-returning call
static void checkString(NSString* actual, NSString* expected, NSString* what)
{
    totalTests++;

    if(YES == [actual isEqualToString:expected])
    {
        testsPassed++;
        NSLog(@"✅ PASS: %@", what);
    }
    else
    {
        NSLog(@"❌ FAIL: %@ (got '%@', expected '%@')", what, actual, expected);
    }

    return;
}

//is a path a wildcard path?
static void testIsWildcardPath(void)
{
    NSLog(@"\n📋 isWildcardPath: telling wildcard paths apart from the rule types that already exist");

    //the ask from issue #176
    checkBool(isWildcardPath(@"/Users/user/.vscode/extensions/ms-vsliveshare.vsliveshare-*/dotnet_modules"), YES, @"a '*' mid-path is a wildcard path");

    //other wildcards fnmatch understands
    checkBool(isWildcardPath(@"/Users/?/foo"), YES, @"a '?' is a wildcard path");
    checkBool(isWildcardPath(@"/Users/[ab]/foo"), YES, @"a '[...]' is a wildcard path");

    //existing rule types, which have their own (cheaper) matching
    checkBool(isWildcardPath(@"*"), NO, @"a global rule ('*') is not a wildcard path");
    checkBool(isWildcardPath(@"/Applications/Foo.app/Contents/MacOS/Foo"), NO, @"a plain path is not a wildcard path");
    checkBool(isWildcardPath(@"/Applications/Foo/*"), NO, @"a directory rule ('/dir/*') is not a wildcard path");

    //a directory rule that also has a wildcard higher up is *not* prefix-matchable
    checkBool(isWildcardPath(@"/Users/*/Library/Foo/*"), YES, @"a directory rule w/ a '*' higher up is a wildcard path");

    //a path that can't name a binary
    checkBool(isWildcardPath(@"relative/*/path"), NO, @"a relative path is not a wildcard path");
    checkBool(isWildcardPath(@""), NO, @"an empty path is not a wildcard path");
    checkBool(isWildcardPath(nil), NO, @"a nil path is not a wildcard path");

    return;
}

//the literal portion of a wildcard path
static void testWildcardPathPrefix(void)
{
    NSLog(@"\n📋 wildcardPathPrefix: the literal head that any match has to start with");

    checkString(wildcardPathPrefix(@"/Users/*/.vscode/extensions/foo-*/bar"), @"/Users/", @"prefix stops at the first '*'");
    checkString(wildcardPathPrefix(@"/Users/foo*/bar"), @"/Users/foo", @"prefix keeps the literal part of a component");
    checkString(wildcardPathPrefix(@"/Users/?/foo"), @"/Users/", @"prefix stops at a '?'");
    checkString(wildcardPathPrefix(@"/no/wildcards/here"), @"/no/wildcards/here", @"a path w/out wildcards is all prefix");
    checkString(wildcardPathPrefix(@""), @"", @"an empty path has an empty prefix");

    return;
}

//matching a path against a wildcard path
static void testWildcardPathMatch(void)
{
    NSLog(@"\n📋 wildcardPathMatch: matching a process path against a rule's wildcard path");

    //issue #176: a vscode extension that changes path on every update
    NSString* vscode = @"/Users/user/.vscode/extensions/ms-vsliveshare.vsliveshare-*/dotnet_modules";

    checkBool(wildcardPathMatch(vscode, @"/Users/user/.vscode/extensions/ms-vsliveshare.vsliveshare-1.0.1510/dotnet_modules"), YES, @"matches the version in the issue");
    checkBool(wildcardPathMatch(vscode, @"/Users/user/.vscode/extensions/ms-vsliveshare.vsliveshare-1.0.2000/dotnet_modules"), YES, @"matches a later version, w/out a new rule");
    checkBool(wildcardPathMatch(vscode, @"/Users/user/.vscode/extensions/some.other.extension-1.0.0/dotnet_modules"), NO, @"does not match a different extension");

    //issue #176: a terraform plugin under a pair of random directories
    NSString* terraform = @"/tmp/*/*/*/.terraform/plugins/darwin_amd64/terraform-provider-aws_v2.50.0_x4";

    checkBool(wildcardPathMatch(terraform, @"/tmp/1wxPXUARbC3osAxqmY_18uishQA/Zy6rJgw8TIQ_iDxN-9GfCyPQZ6Q/datapod/.terraform/plugins/darwin_amd64/terraform-provider-aws_v2.50.0_x4"), YES, @"matches across several wildcard components");
    checkBool(wildcardPathMatch(terraform, @"/tmp/only/two/.terraform/plugins/darwin_amd64/terraform-provider-aws_v2.50.0_x4"), NO, @"does not match w/ a component missing");

    //an app run from the iPhone simulator, whose container is new on each run
    NSString* simulator = @"/Users/user/Library/Developer/CoreSimulator/Devices/*/data/Containers/Bundle/Application/*/MyApp.app/MyApp";

    checkBool(wildcardPathMatch(simulator, @"/Users/user/Library/Developer/CoreSimulator/Devices/9E2A/data/Containers/Bundle/Application/5B11/MyApp.app/MyApp"), YES, @"matches a simulator run");
    checkBool(wildcardPathMatch(simulator, @"/Users/user/Library/Developer/CoreSimulator/Devices/9E2A/data/Containers/Bundle/Application/5B11/OtherApp.app/OtherApp"), NO, @"does not match a different app in the same container");

    //the point of FNM_PATHNAME: a wildcard names one path component, so a rule can't
    //quietly widen to everything nested below it
    checkBool(wildcardPathMatch(@"/Users/*/foo", @"/Users/user/foo"), YES, @"a '*' matches one component");
    checkBool(wildcardPathMatch(@"/Users/*/foo", @"/Users/user/nested/foo"), NO, @"a '*' does not match across a '/'");

    //single character
    checkBool(wildcardPathMatch(@"/Applications/Foo?.app/Contents/MacOS/Foo", @"/Applications/Foo2.app/Contents/MacOS/Foo"), YES, @"a '?' matches a single character");
    checkBool(wildcardPathMatch(@"/Applications/Foo?.app/Contents/MacOS/Foo", @"/Applications/Foo22.app/Contents/MacOS/Foo"), NO, @"a '?' does not match two characters");

    //anchoring: a pattern has to match the whole path, not a piece of it
    checkBool(wildcardPathMatch(@"/Users/*/foo", @"/Users/user/foo/bar"), NO, @"a pattern matches the whole path, not a prefix of it");
    checkBool(wildcardPathMatch(@"/Users/*/foo", @"/var/Users/user/foo"), NO, @"a pattern is anchored at the start");

    //a path w/out wildcards still matches itself
    checkBool(wildcardPathMatch(@"/Applications/Foo.app/Contents/MacOS/Foo", @"/Applications/Foo.app/Contents/MacOS/Foo"), YES, @"a path w/out wildcards matches itself");

    //nothing to match
    checkBool(wildcardPathMatch(@"", @"/Applications/Foo"), NO, @"an empty pattern matches nothing");
    checkBool(wildcardPathMatch(@"/Users/*/foo", @""), NO, @"an empty path matches nothing");

    return;
}

int main(int argc, const char* argv[])
{
    @autoreleasepool
    {
        NSLog(@"🧪 Wildcard Rule Tests");
        NSLog(@"======================");

        testIsWildcardPath();
        testWildcardPathPrefix();
        testWildcardPathMatch();

        NSLog(@"\n🏁 Results");
        NSLog(@"==========");
        NSLog(@"Tests Passed: %d/%d", testsPassed, totalTests);

        if(testsPassed == totalTests)
        {
            NSLog(@"✅ ALL TESTS PASSED!");
            return 0;
        }

        NSLog(@"❌ %d tests failed. Please check implementation.", totalTests - testsPassed);
        return 1;
    }
}
