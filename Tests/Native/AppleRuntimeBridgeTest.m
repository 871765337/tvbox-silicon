#import <Foundation/Foundation.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

extern char *TVAppleRuntimeRequest(const char *, const char *);
static const char *resources;

static void check(const char *input, BOOL error) {
    char *response = TVAppleRuntimeRequest(resources, input);
    NSCAssert(response != NULL, @"Missing native response");
    NSData *data = [NSData dataWithBytes:response length:strlen(response)];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    NSCAssert([json isKindOfClass:NSDictionary.class], @"Invalid JSON response: %@", @(response));
    if (error) {
        NSCAssert([json[@"error"] isKindOfClass:NSString.class], @"Missing error: %@", json);
        NSCAssert([json[@"errorCode"] isEqual:@"embedded_request"], @"Missing localized error code: %@", json);
    } else {
        NSCAssert(strcmp(input, response) == 0, @"Response changed: %@", json);
    }
    free(response);
}

static void *run(void *unused) {
    @autoreleasepool {
        // TestFlight build 29 crashed at strdup(text.UTF8String) for malformed Java text.
        check("high-surrogate", YES);
        check("low-surrogate", YES);
        check("exception", YES);
        check("out-of-memory", YES);
        check("no-response", YES);
        check(NULL, YES);
        check("\xff", YES);
        check("{\"result\":\"中文、日本語、😀 and \\u0000\"}", NO);
        check("{\"result\":\"\"}", NO);
        check("{\"result\":\"recovered\"}", NO);
    }
    return NULL;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSCAssert(argc == 2, @"Expected fixture resource directory");
        resources = argv[1];
        // Exercise concurrent startup, attaching new workers, and recovery after exceptions.
        pthread_t workers[5];
        for (int i = 0; i < 5; i++) NSCAssert(pthread_create(&workers[i], NULL, run, NULL) == 0, @"Could not start worker");
        for (int i = 0; i < 5; i++) NSCAssert(pthread_join(workers[i], NULL) == 0, @"Could not join worker");
        puts("Apple runtime JNI bridge tests passed");
    }
}
