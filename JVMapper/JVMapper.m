#import "JVMapper.h"
#import <objc/runtime.h>

@implementation JVMapper

static const char *getPropertyType(objc_property_t property) {
    const char *attributes = property_getAttributes(property);
    //printf("attributes=%s\n", attributes);
    char buffer[1 + strlen(attributes)];
    strcpy(buffer, attributes);
    char *state = buffer, *attribute;
    while ((attribute = strsep(&state, ",")) != NULL) {
        if (attribute[0] == 'T' && attribute[1] != '@') {
            // it's a C primitive type:
            /*
             if you want a list of what will be returned for these primitives, search online for
             "objective-c" "Property Attribute Description Examples"
             apple docs list plenty of examples of what you get for int "i", long "l", unsigned "I", struct, etc.
             */
            NSString *name = [[NSString alloc] initWithBytes:attribute + 1 length:strlen(attribute) - 1 encoding:NSASCIIStringEncoding];
            return (const char *)[name cStringUsingEncoding:NSASCIIStringEncoding];
        }
        else if (attribute[0] == 'T' && attribute[1] == '@' && strlen(attribute) == 2) {
            // it's an ObjC id type:
            return "id";
        }
        else if (attribute[0] == 'T' && attribute[1] == '@') {
            // it's another ObjC object type:
            NSString *name = [[NSString alloc] initWithBytes:attribute + 3 length:strlen(attribute) - 4 encoding:NSASCIIStringEncoding];
            return (const char *)[name cStringUsingEncoding:NSASCIIStringEncoding];
        }
    }
    return "";
}
/*
 c  A char
 i  An int
 s  A short
 l  A longl is treated as a 32-bit quantity on 64-bit programs.
 q  A long long
 C  An unsigned char
 I  An unsigned int
 S  An unsigned short
 L  An unsigned long
 Q  An unsigned long long
 f  A float
 d  A double
 B  A C++ bool or a C99 _Bool
 */
#define excludedFrameworkPrefixes @[@"NS", @"UI", @"CL", @"CF", @"AB", @"CA", @"CI", @"CG", /* types */ @"c", @"i", @"s", @"q", @"C", @"I", @"S", @"L", @"Q", @"f", @"d", @"B" /* types */ ]

#pragma mark - Check if class type belong to Cocoa Framework

+(BOOL)hasBasicPrefix:(NSString*)classType {
    for (NSString* prefix in excludedFrameworkPrefixes) {
        if ([classType hasPrefix:prefix]) {
            return YES;
        }
    }
    
    return NO;
}

+ (NSArray *)systemExcludedProperties {
    return @[@"observationInfo",@"hash",@"description",@"debugDescription",@"superclass"];
}

#pragma mark - Get properties for a class

+ (NSDictionary *)propertiesForClass:(Class)cls {
    if (cls == NULL) {
        return nil;
    }
    
    NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
    NSArray *systemExcludedProperties = [self systemExcludedProperties];
    
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(cls, &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if(propName) {
            const char *propType = getPropertyType(property);
            NSString *propertyName = [NSString stringWithUTF8String:propName];
            
            if (![systemExcludedProperties containsObject:propertyName]) {
                NSString *propertyType = [NSString stringWithUTF8String:propType];
                results[propertyName] = propertyType;
            }
        }
    }
    free(properties);
    
    // for  inheritance
    if ([cls superclass] != [NSObject class]) {
        [results addEntriesFromDictionary:[self propertiesForClass:[cls superclass]]];
    }
    
    // returning a copy here to make sure the dictionary is immutable
    return [NSDictionary dictionaryWithDictionary:results];
}

#pragma mark - Populate object from data dictionary

+(id)populateObject:(id)obj fromDictionary:(NSDictionary *)dict {
    if (obj == nil) {
        return nil;
    }
    
    // Retrieve list of items to be excluded
    NSArray* excludeArray = nil;
    if ([obj respondsToSelector:@selector(rmExcludedProperties)]) {
        excludeArray = [obj rmExcludedProperties];
    }
    
    Class cls = [obj class];
    
    // Check object for conforming JVMappingKeyPathObject,
    // and if object conform this protocol, we get mapping for this class
    NSDictionary *dataKeysForProperties = nil;
    if ([obj respondsToSelector:@selector(rmDataKeysForClassProperties)]) {
        dataKeysForProperties = [obj rmDataKeysForClassProperties];
    }
    
    // Retrieve property declared in class definition
    NSDictionary* properties = [JVMapper propertiesForClass:cls];
    
    // Since key of object is a string, we need to check the dict contains
    // string as key. If it contains non-string key, the key will be skipped.
    // If key is not inside the object properties, it's skipped too.
    // Otherwise assign value of key from dict to obj
    for (id dataKey in dict) {
        
        // Skip for non-string key
        if ([dataKey isKindOfClass:[NSString class]] == NO) {
            JVMapperLog(@"JVMapper: key must be NSString. Received key \"%@\"", dataKey);
            continue;
        }
        
        // If property and dataKey is different, retrieve property from dataKeysForProperties
        NSString* property = nil;
        if (dataKeysForProperties) {
            property = [[dataKeysForProperties allKeysForObject:dataKey] lastObject];
        }
        if (!property) {
            property = dataKey;
        }
        
        NSString *propertyType = properties[property];
        
        // If property doesn't belong to object, skip it
        if (propertyType == nil) {
            JVMapperLog(@"JVMapper: key \"%@\" does not exist in class or class mapping \"%@\"", property, NSStringFromClass(cls));
            continue;
        }
        
        // If key inside excludeArray, skip it
        if (excludeArray && [excludeArray containsObject:property]) {
            JVMapperLog(@"JVMapper: key \"%@\" is skipped", property);
            continue;
        }
        
        // Get value from dict from dataKey
        id value = dict[dataKey];
        
        // Do not parse NSNull
        if ([value isKindOfClass:[NSNull class]]) {
            continue;
        }
        
        // If the property type is a custom class (not NSDictionary),
        // and the value is a dictionary,
        // convert the dictionary to object of that class
        if (![JVMapper hasBasicPrefix:propertyType] &&
            [value isKindOfClass:[NSDictionary class]]) {
            
            // Init a child attribute with respective class
            Class objCls = NSClassFromString(propertyType);
            
            id childObj;
            
            if ([obj managedObjectContext]) {
                childObj = [[objCls alloc] initWithDictionary: value context: [obj managedObjectContext]];
            } else {
                childObj = [[objCls alloc] init];
            }

            
            if (childObj != nil) {
                
                [JVMapper populateObject:childObj fromDictionary:value];
                
                [obj setValue:childObj forKey:property];
                
            }
            
        }
        
        // Else, set value for key
        else {
            // If the value is basic type and is not array, parse it directly to obj
            if (![value isKindOfClass:[NSArray class]]) {
                
                /*
                 c  A char
                 i  An int
                 s  A short
                 l  A longl is treated as a 32-bit quantity on 64-bit programs.
                 q  A long long
                 C  An unsigned char
                 I  An unsigned int
                 S  An unsigned short
                 L  An unsigned long
                 Q  An unsigned long long
                 f  A float
                 d  A double
                 B  A C++ bool or a C99 _Bool
                 */
                
                    if ([propertyType isEqualToString:@"NSNumber"]) {
                        
                        NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
                        f.numberStyle = NSNumberFormatterDecimalStyle;
                        NSNumber *myNumber = [f numberFromString: [NSString stringWithFormat:@"%@", value ]];
                        
                        [obj setValue:myNumber forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"c"]){
                        
                        [obj setValue: @([value charValue]) forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"i"]){
                        
                        [obj setValue: @([value intValue]) forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"s"]){
                        
                        [obj setValue: @([value shortValue]) forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"l"]){
                        
                        [obj setValue: @([value longValue]) forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"q"]){
                        
                        [obj setValue: @([value longLongValue]) forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"C"]){
                        
                        [obj setValue: @([value unsignedCharValue]) forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"I"]){
                        
                        [obj setValue: @([value unsignedIntValue]) forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"S"]){
                        
                        [obj setValue: @([value unsignedShortValue]) forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"L"]){
                        
                        [obj setValue: @([value unsignedLongValue]) forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"Q"]){
                        
                        [obj setValue: @([value unsignedLongLongValue]) forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"f"]){
                        
                        [obj setValue: @([value floatValue]) forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"d"]){
                        
                        [obj setValue: @([value doubleValue]) forKey:property];
                        
                    }
                    else if ([propertyType isEqualToString:@"B"]){
                        
                        if (([value isKindOfClass:[NSString class]] && [value isEqualToString:@"true"]) || (BOOL) [value intValue]){
                            
                            [obj setValue: @(YES) forKey:property];
                            
                        } else {
                            [obj setValue: @(NO) forKey:property];
                        }
                        
                    } else {
                        
                        [obj setValue:value forKey:property];
                        
                    }

            }
            
            // If property is NSArray or NSMutableArray, and if user provides
            // class of item within the array, parse the value to correct class
            else {
                // If the property type is NSString and the value is array,
                // join them with ","
                if ([propertyType isEqualToString:@"NSString"] \
                    && [value isKindOfClass:[NSArray class]]) {
                    NSArray* arr = (NSArray*) value;
                    NSString* arrString = [arr componentsJoinedByString:@","];
                    [obj setValue:arrString forKey:dataKey];
                }
                
                else if ([obj respondsToSelector:@selector(rmItemClassForArrayProperty:)]) {
                    // Get the class of item inside the array
                    Class itemCls = [obj rmItemClassForArrayProperty:property];
                    
                    // If no item class is specified, set value directly to object property
                    if (!itemCls) {
                        [obj setValue:value forKey:property];
                    } else {
                        NSArray* arr = [[NSArray alloc] init];
                        if ([obj respondsToSelector:@selector(initWithDictionary:context:)]) {
                            // Process value to array with specified item class
                            arr = [JVMapper arrayOfClass:itemCls fromArrayOfDictionary:value context: [obj managedObjectContext]];

                        } else {
                            // Process value to array with specified item class
                            arr = [JVMapper arrayOfClass:itemCls fromArrayOfDictionary:value];
                        }
                        
                        // Set mutable array to property if propertyType is NSMutableArray
                        if ([propertyType isEqualToString:@"NSSet"]) {
                            [obj setValue:[NSSet setWithArray:arr] forKey:property];
                        }
                        
                        // Set mutable array to property if propertyType is NSMutableArray
                        else if ([propertyType isEqualToString:@"NSMutableArray"]) {
                            [obj setValue:[NSMutableArray arrayWithArray:arr] forKey:property];
                        }
                        
                        // Set arr to property if propertyType is NSArray
                        else if ([propertyType isEqualToString:@"NSArray"]) {
                            [obj setValue:arr forKey:property];
                        } else {
                            [obj setValue:value forKey:property];
                        }
                    }
                }
            }
        }
    }
    
    return obj;
}

+ (id)objectWithClass:(Class)cls fromDictionary:(NSDictionary *)dict {
    id obj = [[cls alloc] init];
    
    [JVMapper populateObject:obj fromDictionary:dict];
    
    return obj;
}

#pragma mark - Populate array of class from data array

+(NSArray *)arrayOfClass:(Class)cls fromArrayOfDictionary:(NSArray *)array {
    NSMutableArray *mutableArray = [JVMapper mutableArrayOfClass:cls fromArrayOfDictionary:array];
    
    NSArray *arrWithClass = [NSArray arrayWithArray:mutableArray];
    return arrWithClass;
}

+(NSMutableArray *)mutableArrayOfClass:(Class)cls fromArrayOfDictionary:(NSArray *)array {
    
    if (!array) {
        return nil;
    }
    
    NSMutableArray *mutableArray = [[NSMutableArray alloc] initWithCapacity:[array count]];
    
    for (id item in array) {
        
        // The item must be a dictionary. Otherwise, skip it
        if (![item isKindOfClass:[NSDictionary class]]) {
            JVMapperLog(@"JVMapper: item inside array must be NSDictionary object");
            continue;
        }
        
        // Convert item dictionary to object with predefined class
        id obj = [JVMapper objectWithClass:cls fromDictionary:item];
        [mutableArray addObject:obj];
    }
    
    return mutableArray;
}


#pragma mark - Convert plain object to dictionary

+ (NSDictionary*) mutableDictionaryForObject:(id)obj include:(NSArray*)includeArray {
    NSDictionary* properties = [JVMapper propertiesForClass:[obj class]];
    
    NSDictionary *dataKeysForProperties = nil;
    if ([obj respondsToSelector:@selector(rmDataKeysForClassProperties)]) {
        dataKeysForProperties = [obj rmDataKeysForClassProperties];
    }
    
    NSMutableDictionary* objDict = [NSMutableDictionary dictionary];
    
    for (NSString* property in properties) {
        
        // If includeArray is provided, skip if the property is not inside includeArray
        if (includeArray && ![includeArray containsObject:property]) {
            JVMapperLog(@"JVMapper: key \"%@\" is skipped", property);
            continue;
        }
        
        // Get dataKey for given property
        NSString* dataKey = nil;
        if (dataKeysForProperties) {
            dataKey = dataKeysForProperties[property];
        }
        
        // Fall back to property
        if (!dataKey) {
            dataKey = property;
        }
        
        id val = [obj valueForKey:property];
        
        if (!val) {
            continue;
        }
        
        // If val is custom class, we will try to parse this custom class to NSDictionary
        NSString *propertyType = properties[property];
    
        if ([propertyType isEqualToString:@"d"]){
            
            val = @([val doubleValue]);
            
        } else if ([propertyType isEqualToString:@"q"] ||
                   [propertyType isEqualToString:@"Q"] ||
                   [propertyType isEqualToString:@"l"] ||
                   [propertyType isEqualToString:@"i"]){
            
            val = @([val integerValue]);
            
        } else if ([propertyType isEqualToString:@"B"] ||
                   [propertyType isEqualToString:@"c"]){
            val = @(NO);
            
            if (([val isKindOfClass:[NSString class]] && [val isEqualToString:@"true"]) || (BOOL) [val intValue]){
                
                val = @(YES);
                
            }
            
        }
        
        if (![JVMapper hasBasicPrefix:propertyType] && val) {
            val = [JVMapper mutableDictionaryForObject:val include:nil];
        }
        
        
        [objDict setValue:val forKey:dataKey];
    }
    
    return objDict;
}

+ (NSMutableDictionary *)mutableDictionaryForObject:(id)obj {
    return [JVMapper mutableDictionaryForObject:obj include:nil];
}

+(NSDictionary *)dictionaryForObject:(id)obj include:(NSArray *)includeArray {
    NSMutableDictionary* dict = [JVMapper mutableDictionaryForObject:obj include:includeArray];
    return [NSDictionary dictionaryWithDictionary:dict];
}

+(NSDictionary*)dictionaryForObject:(id)obj {
    NSMutableDictionary *mutableDict = [JVMapper mutableDictionaryForObject:obj];
    return [NSDictionary dictionaryWithDictionary:mutableDict];
}

#pragma mark - Populate array of class from data array with CoreData

+ (id)objectWithClass:(Class)cls fromDictionary:(NSDictionary *)dict context:(NSManagedObjectContext *)context {
    
    id childObj = [[cls alloc] initWithDictionary:dict context: context];
    
    return childObj;
}

+(NSArray *)arrayOfClass:(Class)cls fromArrayOfDictionary:(NSArray *)array context:(NSManagedObjectContext *)context{
    NSMutableArray *mutableArray = [JVMapper mutableArrayOfClass:cls fromArrayOfDictionary:array context:context];
    
    NSArray *arrWithClass = [NSArray arrayWithArray:mutableArray];
    return arrWithClass;
}

+(NSMutableArray *)mutableArrayOfClass:(Class)cls fromArrayOfDictionary:(NSArray *)array context:(NSManagedObjectContext *)context {
    
    if (!array) {
        return nil;
    }
    
    NSMutableArray *mutableArray = [[NSMutableArray alloc] initWithCapacity:[array count]];
    
    for (id item in array) {
        
        // The item must be a dictionary. Otherwise, skip it
        if (![item isKindOfClass:[NSDictionary class]]) {
            JVMapperLog(@"JVMapper: item inside array must be NSDictionary object");
            continue;
        }
        
        // Convert item dictionary to object with predefined class
        id obj = context == nil ? [JVMapper objectWithClass:cls fromDictionary:item] : [JVMapper objectWithClass:cls fromDictionary:item context:context];
        [mutableArray addObject:obj];
    }
    
    return mutableArray;
}


@end
