//
//  MessagePackParser.m
//  Fetch TV Remote
//
//  Created by Chris Hulbert on 23/06/11.
//  Copyright 2011 Digital Five. All rights reserved.
//

#import "MessagePackParser.h"
#include "msgpack_src/msgpack.h"

static const int kUnpackerBufferSize = 1024;

@implementation MessagePackParser {
    msgpack_unpacker unpacker;
}

// This function returns a parsed object that you have the responsibility to release/autorelease (see 'create rule' in apple docs)
+(id) createUnpackedObject:(msgpack_object)obj {
    switch (obj.type) {
        case MSGPACK_OBJECT_BOOLEAN:
            return [[NSNumber alloc] initWithBool:obj.via.boolean];
            break;
        case MSGPACK_OBJECT_POSITIVE_INTEGER:
            return [[NSNumber alloc] initWithUnsignedLongLong:obj.via.u64];
            break;
        case MSGPACK_OBJECT_NEGATIVE_INTEGER:
            return [[NSNumber alloc] initWithLongLong:obj.via.i64];
            break;
        case MSGPACK_OBJECT_DOUBLE:
            return [[NSNumber alloc] initWithDouble:obj.via.dec];
            break;
        case MSGPACK_OBJECT_RAW:
            return [[NSString alloc] initWithBytes:obj.via.raw.ptr length:obj.via.raw.size encoding:NSUTF8StringEncoding];
            break;
        case MSGPACK_OBJECT_ARRAY:
        {
            NSMutableArray *arr = [[NSMutableArray alloc] initWithCapacity:obj.via.array.size];
            msgpack_object* const pend = obj.via.array.ptr + obj.via.array.size;
            for(msgpack_object *p= obj.via.array.ptr;p < pend;p++){
				id newArrayItem = [self createUnpackedObject:*p];
                [arr addObject:newArrayItem];
#if !__has_feature(objc_arc)
                [newArrayItem release];
#endif
            }
            return arr;
        }
            break;
        case MSGPACK_OBJECT_MAP:
        {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:obj.via.map.size];
            msgpack_object_kv* const pend = obj.via.map.ptr + obj.via.map.size;
            for(msgpack_object_kv* p = obj.via.map.ptr; p < pend; p++){
                id key = [self createUnpackedObject:p->key];
                id val = [self createUnpackedObject:p->val];
                [dict setValue:val forKey:key];
#if !__has_feature(objc_arc)
				[key release];
				[val release];
#endif
            }
            return dict;
        }
            break;
        case MSGPACK_OBJECT_NIL:
        default:
            return [NSNull null]; // Since nsnull is a system singleton, we don't have to worry about ownership of it
            break;
    }
}

// Parse the given messagepack data into a NSDictionary or NSArray typically
+ (id)parseData:(NSData*)data {
	msgpack_unpacked msg;
	msgpack_unpacked_init(&msg);
	bool success = msgpack_unpack_next(&msg, data.bytes, data.length, NULL); // Parse it into C-land
	id results = success ? [self createUnpackedObject:msg.data] : nil; // Convert from C-land to Obj-c-land
	msgpack_unpacked_destroy(&msg); // Free the parser
#if !__has_feature(objc_arc)
	return [results autorelease];
#else
    return results;
#endif
}

#pragma mark - Stremaing Deserializer

- (id)init {
    return [self initWithBufferSize:kUnpackerBufferSize];
}

- (id)initWithBufferSize:(int)bufferSize {
    if (self = [super init]) {
        msgpack_unpacker_init(&unpacker, bufferSize);
    }
    return self;
}

// Feed chunked messagepack data into buffer.
- (void)feed:(NSData*)chunk {
    msgpack_unpacker_reserve_buffer(&unpacker, [chunk length]);
    memcpy(msgpack_unpacker_buffer(&unpacker), [chunk bytes], [chunk length]);
    msgpack_unpacker_buffer_consumed(&unpacker, [chunk length]);
}

// Put next parsed messagepack data. If there is not sufficient data, return nil.
- (id)next {
    id unpackedObject;
    msgpack_unpacked result;
    msgpack_unpacked_init(&result);
    if (msgpack_unpacker_next(&unpacker, &result)) {
        msgpack_object obj = result.data;
        unpackedObject = [[self class] createUnpackedObject:obj];
    }
    msgpack_unpacked_destroy(&result);
    
#if !__has_feature(objc_arc)
    return [unpackedObject autorelease];
#else
    return unpackedObject;
#endif
}

@end
