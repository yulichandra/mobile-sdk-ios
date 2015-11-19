//
//  NUProduct.h
//  NextUserKit
//
//  Created by Dino on 11/18/15.
//  Copyright © 2015 NextUser. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NUProduct : NSObject

+ (instancetype)productWithName:(NSString *)name;

@property (nonatomic) NSString *name;
@property (nonatomic) NSString *SKU;
@property (nonatomic) NSString *category;
@property (nonatomic) double price;
@property (nonatomic) NSUInteger quantity; // defautls to 1
@property (nonatomic) NSString *productDescription;

@end