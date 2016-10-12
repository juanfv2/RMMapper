//
//  RMItem.h
//  JVMapperExample
//
//  Created by Thomas Dao on 24/9/14.
//  Copyright (c) 2014 Roomorama. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JVMapper.h"

@interface RMItem : NSObject <JVMapping>

@property (nonatomic, strong) NSString* id;
@property (nonatomic, strong) NSString* type;
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSArray* topping;

@end
