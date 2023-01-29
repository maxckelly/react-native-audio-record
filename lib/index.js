import { NativeModules, NativeEventEmitter, } from 'react-native';
import { isNativeModuleLoaded } from './helpers';
const { RNAudioRecord } = NativeModules;
let EventEmitter;
let AudioRecord;
if (isNativeModuleLoaded(RNAudioRecord)) {
    EventEmitter = new NativeEventEmitter(RNAudioRecord);
}
export var AudioRecordEvent;
(function (AudioRecordEvent) {
    AudioRecordEvent["data"] = "data";
    AudioRecordEvent["format"] = "format";
    AudioRecordEvent["timer"] = "timer";
})(AudioRecordEvent || (AudioRecordEvent = {}));
const eventsMap = {
    data: AudioRecordEvent.data,
    format: AudioRecordEvent.format,
    timer: AudioRecordEvent.timer,
};
AudioRecord.recorderOn = (event, callback) => {
    const nativeEvent = eventsMap[event];
    if (!nativeEvent) {
        throw new Error('Invalid event');
    }
    EventEmitter.removeAllListeners(nativeEvent);
    return EventEmitter.addListener(nativeEvent, callback);
};
AudioRecord.initRecorder = (options, formatCallback) => {
    AudioRecord.recorderOn(AudioRecordEvent.format, formatCallback);
    RNAudioRecord.initialise(options);
};
AudioRecord.recorderStart = (playbackOptions) => RNAudioRecord.start(playbackOptions);
AudioRecord.recorderStop = () => RNAudioRecord.stop();
export default AudioRecord;
