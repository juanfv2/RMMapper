//
//  NSObject+TDCopy.m
//  Roomorama
//
//  Created by Roomorama on 27/12/12.
//  Copyright (c) 2012 Roomorama. All rights reserved.
//

#import "NSObject+JVCopyable.h"
#import "JVMapper.h"


@implementation NSObject (RMCopyable)

-(instancetype)copyWithZone:(NSZone *)zone {
    typeof(self) copiedObj = [[[self class] allocWithZone:zone] init];
    if (copiedObj) {
        NSDictionary* properties = [JVMapper propertiesForClass:[self class]];
        // Retrieve excluded properties
        NSArray *excludedProperties = nil;
        
        if ([self respondsToSelector:@selector(rmExcludedProperties)]) {
            excludedProperties = [self performSelector:@selector(rmExcludedProperties)];
        }
        for (NSString* key in properties) {
            if (!excludedProperties || ![excludedProperties containsObject:key]) {
                id val = [self valueForKey:key];
                [copiedObj setValue:val forKey:key];
            }
        }
    }
    return copiedObj;
}


@end
