#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#ifdef DEBUG
#   define JVMapperLog(__FORMAT__, ...) NSLog(__FORMAT__, ##__VA_ARGS__)
#else
#   define JVMapperLog(...) do {} while (0)
#endif

/**
 * This protocol let you control conversion between data key
 * and class properties
 */
@protocol JVMapping <NSObject>

@optional

// Allow properties to be excluded from parsing data
- (NSArray *)jvExcludedProperties;

// Mapping for properties keys to class properties
- (NSDictionary *)jvDataKeysForClassProperties;

// Parse item within array
- (Class)jvItemClassForArrayProperty:(NSString *)property;


@end

/**
 * This protocol let you control conversion between data key
 * and class properties
 */
@protocol JVMappingSQ <JVMapping>

// Allow properties to be excluded from saving data
- (NSArray *)jvExcludedPropertiesDB;

// Init method with SQLite
- (id)initWithDictionaryAndSave:(NSDictionary *)dictionary;

@end

/**
 * This protocol let you control conversion between data key
 * and class properties
 */
@protocol JVMappingCD <JVMapping>

// Init method with CoreData
- (instancetype)initWithDictionary:(NSDictionary *)dictionary context:(NSManagedObjectContext *)context;

@end

@interface JVMapper : NSObject

#pragma mark - Get properties for a class

/**
 Answer from http://stackoverflow.com/questions/754824/get-an-object-attributes-list-in-objective-c/13000074#13000074
 
 Return dictionary of property name and type from a class.
 Useful for Key-Value Coding.
 */
+ (NSDictionary *)propertiesForClass:(Class)cls;

/** Populate existing object with values from dictionary
 */
+ (id)populateObject:(id)obj fromDictionary:(NSDictionary *)dict;

/** Create a new object with given class and populate it with value from dictionary
 */
+ (id)objectWithClass:(Class)cls fromDictionary:(NSDictionary *)dict;


#pragma mark - Convert plain object to dictionary

/** Convert an object to a dictionary
 */
+ (NSDictionary *)dictionaryForObject:(id)obj;

+ (NSDictionary *)dictionaryForObject:(id)obj exclude:(NSArray *)excludeArray;

+ (NSMutableDictionary *)mutableDictionaryForObject:(id)obj;

+ (NSMutableDictionary *)mutableDictionaryForObject:(id)obj exclude:(NSArray *)excludeArray;

/** Convert an array of dict to array of object with predefined class
 */
+ (NSArray *)arrayOfClass:(Class)cls fromArrayOfDictionary:(NSArray *)array;

+ (NSMutableArray *)mutableArrayOfClass:(Class)cls fromArrayOfDictionary:(NSArray *)array;


#pragma mark - Populate array of class from data array with CoreData

/** Create a new object with given class and populate it with value from dictionary
 */
+ (id)objectWithClass:(Class)cls fromDictionary:(NSDictionary *)dict context:(NSManagedObjectContext *)context;

/** Convert an array of dict to array of object with predefined class with CoreData
 */
+ (NSArray *)arrayOfClass:(Class)cls fromArrayOfDictionary:(NSArray *)array context:(NSManagedObjectContext *)context;

+ (NSMutableArray *)mutableArrayOfClass:(Class)cls fromArrayOfDictionary:(NSArray *)array context:(NSManagedObjectContext *)context;
/* */
@end
