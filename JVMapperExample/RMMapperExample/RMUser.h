//
//  RMUser.h
//  JVMapperExample
//
//  Created by Roomorama on 28/6/13.
//  Copyright (c) 2013 Roomorama. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+JVArchivable.h"
#import "JVMapper.h"

@interface RMUser : NSObject <JVMapping>

@property (nonatomic, retain) NSNumber* id;
@property (nonatomic, retain) NSString* display;
@property (nonatomic, assign) BOOL certified;
@property (nonatomic, retain) NSString* url;

@end
