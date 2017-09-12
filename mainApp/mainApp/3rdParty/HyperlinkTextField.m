//
//  HyperlinkTextField.m
//  NSTextFieldHyperlinks
//
//  Created by Toomas Vahter on 25.12.12.
//  Copyright (c) 2012 Toomas Vahter. All rights reserved.
//
//  This content is released under the MIT License (http://www.opensource.org/licenses/mit-license.php).
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "HyperlinkTextField.h"

@interface HyperlinkTextField ()
@property (nonatomic, readonly) NSArray *hyperlinkInfos;
@property (nonatomic, readonly) NSTextView *textView;

- (void)_resetHyperlinkCursorRects;
@end

#define kHyperlinkInfoCharacterRangeKey @"range"
#define kHyperlinkInfoURLKey            @"url"
#define kHyperlinkInfoRectKey           @"rect"

@implementation HyperlinkTextField

- (void)_hyperlinkTextFieldInit
{
    [self setEditable:NO];
    [self setSelectable:NO];
}


- (id)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self _hyperlinkTextFieldInit];
    }
    
    return self;
}


- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
    {
        [self _hyperlinkTextFieldInit];
    }
    
    return self;
}


- (void)resetCursorRects
{
    [super resetCursorRects];
    [self _resetHyperlinkCursorRects];
}


- (void)_resetHyperlinkCursorRects
{
    for (NSDictionary *info in self.hyperlinkInfos)
    {
        [self addCursorRect:[[info objectForKey:kHyperlinkInfoRectKey] rectValue] cursor:[NSCursor pointingHandCursor]];
    }
}


#pragma mark -
#pragma mark Accessors

- (NSArray *)hyperlinkInfos
{
    NSMutableArray *hyperlinkInfos = [[NSMutableArray alloc] init];
    NSRange stringRange = NSMakeRange(0, [self.attributedStringValue length]);
    __block NSTextView *textView = self.textView;
    [self.attributedStringValue enumerateAttribute:NSLinkAttributeName inRange:stringRange options:0 usingBlock:^(id value, NSRange range, BOOL *stop)
    {
        if (value)
        {
            NSUInteger rectCount = 0;
            NSRectArray rectArray = [textView.layoutManager rectArrayForCharacterRange:range withinSelectedCharacterRange:range inTextContainer:textView.textContainer rectCount:&rectCount];
            for (NSUInteger i = 0; i < rectCount; i++)
            {
                [hyperlinkInfos addObject:@{kHyperlinkInfoCharacterRangeKey : [NSValue valueWithRange:range], kHyperlinkInfoURLKey : value, kHyperlinkInfoRectKey : [NSValue valueWithRect:rectArray[i]]}];
            }
        }
    }];
    
    return [hyperlinkInfos count] ? hyperlinkInfos : nil;
}


- (NSTextView *)textView
{
    // Font used for displaying and frame calculations must match
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedStringValue];
    NSFont *font = [attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    
    if (!font)
        [attributedString addAttribute:NSFontAttributeName value:self.font range:NSMakeRange(0, [attributedString length])];
    
    NSRect textViewFrame = [self.cell titleRectForBounds:self.bounds];
    NSTextView *textView = [[NSTextView alloc] initWithFrame:textViewFrame];
    [textView.textStorage setAttributedString:attributedString];

    return textView;
}


#pragma mark -
#pragma mark Mouse Events

- (void)mouseUp:(NSEvent *)theEvent
{
    NSTextView *textView = self.textView;
    NSPoint localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSUInteger index = [textView.layoutManager characterIndexForPoint:localPoint inTextContainer:textView.textContainer fractionOfDistanceBetweenInsertionPoints:NULL];
    
    if (index != NSNotFound)
    {
        for (NSDictionary *info in self.hyperlinkInfos)
        {
            NSRange range = [[info objectForKey:kHyperlinkInfoCharacterRangeKey] rangeValue];
            if (NSLocationInRange(index, range))
            {
                NSURL *url = [info objectForKey:kHyperlinkInfoURLKey];
                [[NSWorkspace sharedWorkspace] openURL:url];
            }
        }
    }
}

@end
