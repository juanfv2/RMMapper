//
//  NSObject+TDArchivable.m
//  Roomorama
//
//  Created by DAO XUAN DUNG on 20/11/12.
//
//

#import "NSObject+JVArchivable.h"
#import "JVMapper.h"

@implementation NSObject (JVArchivable)

- (void)encodeWithCoder:(NSCoder *)encoder {
    // Encode properties, other class variables, etc
    NSDictionary* propertyDict = [JVMapper propertiesForClass:[self class]];
    
    // Retrieve excluded properties
    NSArray *excludedProperties = nil;
    
    if ([self respondsToSelector:@selector(jvExcludedProperties)]) {
        excludedProperties = [self performSelector:@selector(jvExcludedProperties)];
    }
    
    for (NSString* key in propertyDict) {
        if (!excludedProperties || ![excludedProperties containsObject:key]) {
            id value = [self valueForKey:key];
            [encoder encodeObject:value forKey:key];
        }        
    }
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    if([self init]) {
        // Decode properties, other class vars
        NSDictionary* propertyDict = [JVMapper propertiesForClass:[self class]];
        
        // Retrieve excluded properties
        NSArray *excludedProperties = nil;
        
        if ([self respondsToSelector:@selector(jvExcludedProperties)]) {
            excludedProperties = [self performSelector:@selector(jvExcludedProperties)];
        }
        
        for (NSString* key in propertyDict) {
            if (!excludedProperties || ![excludedProperties containsObject:key]) {
                id value = [decoder decodeObjectForKey:key];
                [self setValue:value forKey:key];
            }
        }
    }
    return self;
}

@end
