//
//  RNAudioRecordBridge.m
//  RNAudioRecord
//
//  Created by James Kemp on 17/5/2022.
//

#import "React/RCTEventEmitter.h"
#import "React/RCTBridgeModule.h"


@interface
    RCT_EXTERN_MODULE(RNAudioRecord, RCTEventEmitter)
    RCT_EXTERN_METHOD(initialise:(NSDictionary *) options)
    RCT_EXTERN_METHOD(start:(NSDictionary *) playbackOptions)
    RCT_EXTERN_METHOD(stop:
                        (RCTPromiseResolveBlock)resolve
                        rejecter:(RCTPromiseRejectBlock)reject)
@end
