//
//  ObjCExceptionCatcher.h
//  CodeEditTextViewObjC
//

#ifndef ObjCExceptionCatcher_h
#define ObjCExceptionCatcher_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs `block`, returning the Objective-C exception it raised, or nil if it returned normally.
///
/// Swift can't catch an `NSException`, and one unwinding through Swift frames skips their `defer`s, so a lock
/// taken around code that might raise one stays locked for good. This lets that code release it.
NSException *_Nullable CatchObjCException(NS_NOESCAPE void (^block)(void));

NS_ASSUME_NONNULL_END

#endif /* ObjCExceptionCatcher_h */
