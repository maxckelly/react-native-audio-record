#import "RNAudioRecord-Bridging-Header.h"
#import <Foundation/Foundation.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>


@interface RCT_EXTERN_MODULE(RNAudioRecord, RCTEventEmitter)

RCT_EXTERN_METHOD(initialise:(NSDictionary *) options)
RCT_EXTERN_METHOD(start:(NSDictionary *) playbackOptions)
RCT_EXTERN_METHOD(stop:
                    (RCTPromiseResolveBlock)resolve
                    rejecter:(RCTPromiseRejectBlock)reject)
@end
