//
//  ObjCExceptionCatcher.m
//  CodeEditTextViewObjC
//

#import <Foundation/Foundation.h>
#import "ObjCExceptionCatcher.h"

NSException *_Nullable CatchObjCException(NS_NOESCAPE void (^block)(void)) {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return exception;
    }
}
