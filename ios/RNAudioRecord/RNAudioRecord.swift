//
//  RNAudioRecord.swift
//  RNAudioRecord
//
import Foundation
import UIKit
import AVFoundation


@available(iOS 9.0, *)
struct AudioRecordState {
    var queue: UnsafeMutablePointer<AudioQueueRef?>
    var recordFormat: AudioStreamBasicDescription
    var recordBuffers: [AudioQueueBufferRef?]
    var recordBufferByteSize: UInt32?
    var convertBuffer: UnsafeMutableBufferPointer<UInt8>
    var convertBufferByteSize: UInt32
    var nextConvertBuffer: Int
    var isRunning: Bool
    var timer: Timer?
    var elapsedSeconds: Int
    var recordStartTimestamp: Double
    var recordStartDuration: Double
    var rnAR: RNAudioRecord?
    var codec: AudioCodec?
    var upstreamFormat: String?
}
struct ConverterFormats {
    var pcmFormat: AudioStreamBasicDescription
    var pcmForOpusFormat: AudioStreamBasicDescription
    var pcmForFlacFormat: AudioStreamBasicDescription
    var opusFormat: AudioStreamBasicDescription
    var flacFormat: AudioStreamBasicDescription
}
@available(iOS 9.0, *)
@objc(RNAudioRecord)
open class RNAudioRecord: RCTEventEmitter {
    
    var _recordState: AudioRecordState
    let kNumberRecordBuffers = 3
    let kFallbackRecordBufferSize = 2000
    let kConvertBufferSize = 10000
    var formats = ConverterFormats(pcmFormat: AudioStreamBasicDescription(), pcmForOpusFormat: AudioStreamBasicDescription(), pcmForFlacFormat: AudioStreamBasicDescription(), opusFormat: AudioStreamBasicDescription(), flacFormat: AudioStreamBasicDescription())

    func getRecordBufferByteSize() -> UInt32 {
        if (_recordState.upstreamFormat != "PCM") {
            let buffSizeArray = getCodecPropertyArray(_recordState.codec!, kAudioCodecPropertyInputBufferSize, UInt32.self)
            return buffSizeArray[0]
        }
        else {
            return UInt32(kFallbackRecordBufferSize)
        }
    }
    
    override init() {
        _recordState = AudioRecordState(
            queue: UnsafeMutablePointer<AudioQueueRef?>.allocate(capacity: 1),
            recordFormat: formats.pcmFormat,
            recordBuffers: [AudioQueueBufferRef?](repeating:nil, count:kNumberRecordBuffers),
            convertBuffer: UnsafeMutableBufferPointer<UInt8>.allocate(capacity: kConvertBufferSize),
            convertBufferByteSize: UInt32(kConvertBufferSize),
            nextConvertBuffer: 0,
            isRunning: false,
            elapsedSeconds: 0,
            recordStartTimestamp: 0,
            recordStartDuration: 0
        )
        super.init()
        _recordState.rnAR = self
    }
    
    // Removes React native warning re requiresMainQueueSetup
    public override static func requiresMainQueueSetup() -> Bool {
        return true
    }

    @objc
    func initialise(_ options: NSDictionary) {
        NSLog("RNAudioRecord initialise")
        configureFormats(options)
        _recordState.upstreamFormat = findAndInitialiseCodec(forceUsePCM: false)
        _recordState.recordBufferByteSize = getRecordBufferByteSize()
        logCodecInfo()
        NSLog("RNAudioRecord using format " + _recordState.upstreamFormat!)

        // TODO: allocate record buffers here instead of in start()
        
        // setup timer
        _recordState.elapsedSeconds = 0;
        sendEvent(withName: "format", body: _recordState.upstreamFormat)
    }
    
    func logCodecInfo() {
        if (_recordState.upstreamFormat != "PCM") {
            logPropertyArray("kAudioCodecPropertySupportedInputFormats", getCodecPropertyArray(_recordState.codec!, kAudioCodecPropertySupportedInputFormats, AudioStreamBasicDescription.self))
            logPropertyArray("kAudioCodecPropertySupportedOutputFormats", getCodecPropertyArray(_recordState.codec!, kAudioCodecPropertySupportedOutputFormats, AudioStreamBasicDescription.self))
            logPropertyArray("kAudioCodecPropertyInputBufferSize", getCodecPropertyArray(_recordState.codec!, kAudioCodecPropertyInputBufferSize, UInt32.self))
            logPropertyArray("kAudioCodecPropertyPacketFrameSize", getCodecPropertyArray(_recordState.codec!, kAudioCodecPropertyPacketFrameSize, UInt32.self))
            logPropertyArray("kAudioCodecPropertyQualitySetting", getCodecPropertyArray(_recordState.codec!, kAudioCodecPropertyQualitySetting, UInt32.self))
            logPropertyArray("kAudioCodecPropertyCurrentOutputSampleRate", getCodecPropertyArray(_recordState.codec!, kAudioCodecPropertyCurrentOutputSampleRate, UInt32.self))
        }
    }
    
    func logPropertyArray<T>(_ propertyName: String, _ propertyArray: [T]) {
        for property in propertyArray {
            NSLog("RNAudioRecord " + propertyName + " " + String(describing: property))
        }
    }
                                                                                               

    func osTypeToString(_ fileType: OSType) -> String {
        let chars = [24, 16, 8, 0].map { Character(UnicodeScalar(UInt8(fileType >> $0 & 0xFF)))}
        return String(chars)
    }
    
    func convertCfTypeToString(_ cfValue: Unmanaged<CFString>!) -> String?{
        let value = Unmanaged.fromOpaque(
            cfValue.toOpaque()).takeUnretainedValue() as CFString
        if CFGetTypeID(value) == CFStringGetTypeID(){
            return value as String
        } else {
            return nil
        }
    }
    
    @objc
    func start(_ playbackOptions: NSDictionary) {
        NSLog("RNAudioRecord start")
        let sharedInstance = AVAudioSession.sharedInstance()
        do {
            try sharedInstance.setCategory(AVAudioSession.Category.record)
            if playbackOptions["allowHaptics"] as? Bool ?? false {
                if #available(iOS 13.0, *) {
                    try sharedInstance.setAllowHapticsAndSystemSoundsDuringRecording(true)
                }
            }
        } catch {
            NSLog("RNAudioRecord unable exception managing AVAudioSession")
        }

        _recordState.isRunning = true
        
        AudioQueueNewInput(&_recordState.recordFormat, handleInputBuffer, &_recordState, nil, nil, 0, _recordState.queue)
        var i = 0;
        repeat {
            AudioQueueAllocateBuffer((_recordState.queue.pointee)!, _recordState.recordBufferByteSize!, &_recordState.recordBuffers[i])
            AudioQueueEnqueueBuffer((_recordState.queue.pointee)!, _recordState.recordBuffers[i]!, 0, nil)
            i += 1
        } while (i < kNumberRecordBuffers)
        AudioQueueStart((_recordState.queue.pointee)!, nil);

        _recordState.recordStartDuration = playbackOptions["elapsedSeconds"] as? Double ?? 0
        _recordState.elapsedSeconds = Int(_recordState.recordStartDuration.rounded())
        _recordState.recordStartTimestamp = now()
        
        DispatchQueue.main.async{
            self._recordState.timer = Timer.scheduledTimer(
                                                            timeInterval: 1,
                                                            target:self,
                                                            selector:#selector(self.timerInterval),
                                                            userInfo:nil,
                                                            repeats:true)
        }
    }
    
    func now() -> Double {
        return NSDate().timeIntervalSince1970 * 1000
    }
    
    @objc func timerInterval() -> Void {
       _recordState.elapsedSeconds+=1
        sendEvent(withName: "timer", body: String(_recordState.elapsedSeconds))
    }
    
    open func dealloc() {
        NSLog("RNAudioRecord dealloc");
        AudioQueueDispose((_recordState.queue.pointee)!, true);
    }
    
    @objc
    func stop(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void {
        NSLog("RNAudioRecord stop")
        if (_recordState.isRunning) {
            _recordState.isRunning = false;
            AudioQueueStop((_recordState.queue.pointee)!, true);
            AudioQueueDispose((_recordState.queue.pointee)!, true);
            _recordState.timer?.invalidate()
            _recordState.timer = nil;
            let sharedInstance = AVAudioSession.sharedInstance()
            do {
                try sharedInstance.setCategory(AVAudioSession.Category.playback)
            } catch {
                NSLog("RNAudioRecord unable exception managing AVAudioSession")
            }

        }
        let recordFinishDuration: Double = _recordState.recordStartDuration + ((now() - _recordState.recordStartTimestamp)/1000)
        resolve(((recordFinishDuration * 10).rounded() / 10))
    }

    open override func supportedEvents() -> [String]! {
        return ["data", "format", "timer"]
    }

    func findAndInitialiseCodec(forceUsePCM: Bool?) -> String {
        if (!(forceUsePCM ?? false)) {
            var opusCodecDescription = AudioComponentDescription()
            opusCodecDescription.componentType = "aenc".osType()
            opusCodecDescription.componentSubType = "opus".osType()
            var flacCodecDescription = AudioComponentDescription()
            flacCodecDescription.componentType = "aenc".osType()
            flacCodecDescription.componentSubType = "flac".osType()

            var component: AudioComponent?
            let codecP = UnsafeMutablePointer<AudioComponentInstance?>.allocate(capacity: 1)

            // opus setup
            component = AudioComponentFindNext(nil, &opusCodecDescription)!
            if (component != nil) {
                if !checkError(AudioComponentInstanceNew(component!, codecP), withError:"Unable to get audio component instance") {
                    _recordState.codec = codecP.pointee
                    if(!checkError(AudioCodecInitialize(_recordState.codec!, &formats.pcmForOpusFormat, &formats.opusFormat, nil, 0), withError: "Unable to initialise opus codec"))
                    {
                        _recordState.recordFormat = formats.pcmForOpusFormat
                        return "OPUS"
                    }
                }
            } 

            // flac setup
            component = AudioComponentFindNext(nil, &flacCodecDescription)!
            if (component != nil) {
                if !checkError(AudioComponentInstanceNew(component!, codecP), withError:"Unable to get audio component instance") {
                    _recordState.codec = codecP.pointee

                    if(!checkError(AudioCodecInitialize(_recordState.codec!, &formats.pcmForFlacFormat, &formats.flacFormat, nil, 0), withError: "Unable to initialise opus codec"))
                    {
                        _recordState.recordFormat = formats.pcmForFlacFormat
                        return "FLAC"
                    }
                }
            }

        }

        // couldn't get either so fall back to PCM
        _recordState.recordFormat = formats.pcmFormat
        return "PCM"
    }
    
    func configureFormats(_ options: NSDictionary) {
        formats.pcmFormat.mSampleRate = options["sampleRate"] as? Double ?? 48000
        formats.pcmFormat.mChannelsPerFrame  = UInt32(options["channels"] as? Int ?? 1)
        formats.pcmFormat.mBitsPerChannel    = UInt32(options["bitsPerSample"] as? Int ?? 16)
        formats.pcmFormat.mBytesPerPacket    = (formats.pcmFormat.mBitsPerChannel / 8) * formats.pcmFormat.mChannelsPerFrame
        formats.pcmFormat.mBytesPerFrame     = formats.pcmFormat.mBytesPerPacket;
        formats.pcmFormat.mFramesPerPacket   = 1;
        formats.pcmFormat.mReserved          = 0;
        formats.pcmFormat.mFormatID          = kAudioFormatLinearPCM;
        formats.pcmFormat.mFormatFlags       = formats.pcmFormat.mBitsPerChannel == 8 ? kLinearPCMFormatFlagIsPacked : (kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked);

        formats.pcmForFlacFormat.mSampleRate = options["sampleRate"] as? Double ?? 48000
        formats.pcmForFlacFormat.mChannelsPerFrame  = UInt32(options["channels"] as? Int ?? 1)
        formats.pcmForFlacFormat.mBitsPerChannel    = UInt32(options["bitsPerSample"] as? Int ?? 16)
        formats.pcmForFlacFormat.mBytesPerPacket    = (formats.pcmForFlacFormat.mBitsPerChannel / 8) * formats.pcmForFlacFormat.mChannelsPerFrame
        formats.pcmForFlacFormat.mBytesPerFrame     = formats.pcmForFlacFormat.mBytesPerPacket;
        formats.pcmForFlacFormat.mFramesPerPacket   = 1;
        formats.pcmForFlacFormat.mReserved          = 0;
        formats.pcmForFlacFormat.mFormatID          = kAudioFormatLinearPCM;
        formats.pcmForFlacFormat.mFormatFlags       = 12;
        
        formats.pcmForOpusFormat.mSampleRate = options["sampleRate"] as? Double ?? 48000
        formats.pcmForOpusFormat.mChannelsPerFrame  = UInt32(options["channels"] as? Int ?? 1)
        formats.pcmForOpusFormat.mBitsPerChannel    = 32
        formats.pcmForOpusFormat.mBytesPerPacket    = 4
        formats.pcmForOpusFormat.mBytesPerFrame     = 4
        formats.pcmForOpusFormat.mFramesPerPacket   = 1;
        formats.pcmForOpusFormat.mReserved          = 0;
        formats.pcmForOpusFormat.mFormatID          = kAudioFormatLinearPCM;
        formats.pcmForOpusFormat.mFormatFlags       = 9

        formats.flacFormat.mChannelsPerFrame  = UInt32(options["channels"] as? Int ?? 1)
        formats.flacFormat.mBitsPerChannel    = UInt32(options["bitsPerSample"] as? Int ?? 16)
        formats.flacFormat.mFormatID = kAudioFormatFLAC;
        formats.flacFormat.mFormatFlags = kAppleLosslessFormatFlag_16BitSourceData;

        formats.opusFormat.mSampleRate = options["sampleRate"] as? Double ?? 44100
        formats.opusFormat.mChannelsPerFrame  = UInt32(options["channels"] as? Int ?? 1)
        formats.opusFormat.mBitsPerChannel    = 0
        formats.opusFormat.mFormatID = kAudioFormatOpus;
        formats.opusFormat.mFormatFlags = 0;
        formats.opusFormat.mBytesPerPacket   = 0;
        formats.opusFormat.mBytesPerFrame   = 0;
        formats.opusFormat.mFramesPerPacket   = 960//960//2880//960//160//480//2880
        formats.opusFormat.mReserved          = 0;
    }
}

func checkError(_ error: OSStatus, withError string: @autoclosure ()->String) -> Bool{
     if error == noErr {
         return false
     }
    else {
        NSLog("RNAudioRecord error " + string() + String(error))
    }
     return true
 }

@available(iOS 9.0, *)
func handleInputBuffer(inUserData: UnsafeMutableRawPointer?,
                       inQueue: AudioQueueRef,
                       inBuffer: AudioQueueBufferRef,
                       inStartTime: UnsafePointer<AudioTimeStamp>,
                       inNumPackets: UInt32,
                       inPacketDesc: UnsafePointer<AudioStreamPacketDescription>?) -> Void {

    let recordState = inUserData?.load(as: AudioRecordState.self)
    
    if !recordState!.isRunning {
        return
    }
    
    let inBytes = inBuffer.pointee.mAudioData
    let inBytesCount = inBuffer.pointee.mAudioDataByteSize

    if (recordState?.upstreamFormat == "PCM") {
        let data = NSData.init(bytes:inBytes, length:Int(inBytesCount))
        let dataStr = data.base64EncodedString(options: NSData.Base64EncodingOptions.endLineWithCarriageReturn)
        // send the data
        recordState?.rnAR?.sendEvent(withName: "data", body: dataStr)
    }
    else {
        // handle conversion for FLAC or OPUS
        // logic is complicated by the need to fit the provided data
        // into the available input buffer
        // and avoid overspill which would cause
        // audio corruption
    
        var inBytesCounter: UInt32 = 0
        let codecInputBufferSize = getCodecPropertyArray((recordState?.codec)!, kAudioCodecPropertyInputBufferSize, UInt32.self).first
        repeat {
            let inBytesCountee = inBytes.advanced(by: Int(inBytesCounter))
            let usedCodecInputBufferSize = getCodecPropertyArray((recordState?.codec)!, kAudioCodecPropertyUsedInputBufferSize, UInt32.self).first
            
            let remainingCodecInputBufferSize = codecInputBufferSize! - usedCodecInputBufferSize!
            var ioNumberPackets = UInt32(0)
            var ioInputDataByteSize = min((inBytesCount - inBytesCounter), remainingCodecInputBufferSize)

            var ret = AudioCodecAppendInputData(recordState!.codec!,
                                                inBytesCountee,
                                         &ioInputDataByteSize,
                                         &ioNumberPackets,
                                         nil)
            inBytesCounter += ioInputDataByteSize

            var outputDataSize = UInt32(recordState!.convertBufferByteSize)
            var ioNumPackets = UInt32(1) // requesting one packet
            var outputStatus = UInt32(0)
            let useConvertBuffer = recordState!.convertBuffer
            repeat {
                let ret = AudioCodecProduceOutputPackets(recordState!.codec!,
                                                     useConvertBuffer.baseAddress!,
                                                     &outputDataSize,
                                                     &ioNumPackets,
                                                     nil,
                                                     &outputStatus)

                // send the data
                if (outputDataSize > 0) {
                    let data = NSData.init(bytes: useConvertBuffer.baseAddress, length:Int(outputDataSize))
                    let dataStr = data.base64EncodedString(options: NSData.Base64EncodingOptions.endLineWithCarriageReturn)
                    recordState!.rnAR?.sendEvent(withName: "data", body: dataStr)
                }
            } while (outputStatus == kAudioCodecProduceOutputPacketSuccessHasMore)
        } while (inBytesCounter < inBytesCount)
    }
    AudioQueueEnqueueBuffer((recordState?.queue.pointee)!, inBuffer, 0, nil);

}

extension String {
    public func osType() -> OSType {
       var result:UInt = 0

       if let data = self.data(using: .macOSRoman), data.count == 4
       {
            data.withUnsafeBytes { (ptr:UnsafePointer<UInt8>) in
                for i in 0..<data.count {
                    result = result << 8 + UInt(ptr[i])
                }
            }
       }
       return OSType(result)
    }
}

func getCodecPropertyArray<T>(_ codec: AudioCodec, _ propId: AudioCodecPropertyID, _ dataType: T.Type) -> [T] {
    var outSize: UInt32 = 0
    var writable: DarwinBoolean = false
    
    AudioCodecGetPropertyInfo(codec, propId, &outSize, &writable)
    let p = UnsafeMutablePointer<UInt32>.allocate(capacity: Int(outSize))

    checkError(AudioCodecGetProperty(codec, propId, &outSize, p), withError: "Error in AudioCodecGetProperty")
    
    let itemSize: Int = MemoryLayout<T>.size
    let itemCount = Int(outSize) / itemSize
    var i = 0;
    let rawPointer = UnsafeMutableRawPointer(p)

    var array: [T] = []
    
    while (i<itemCount) {
        let format = rawPointer.advanced(by: (MemoryLayout<T>.size * i)).load(as: T.self)
        array.append(format)
        i+=1
    }
    return array
}
