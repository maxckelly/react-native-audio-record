"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.recorderOn = exports.recorderStop = exports.recorderStart = exports.initRecorder = exports.AudioRecordEvent = void 0;
const react_native_1 = require("react-native");
const helpers_1 = require("./helpers");
const { RNAudioRecord } = react_native_1.NativeModules;
let EventEmitter;
if ((0, helpers_1.isNativeModuleLoaded)(RNAudioRecord)) {
    EventEmitter = new react_native_1.NativeEventEmitter(RNAudioRecord);
}
var AudioRecordEvent;
(function (AudioRecordEvent) {
    AudioRecordEvent["data"] = "data";
    AudioRecordEvent["format"] = "format";
    AudioRecordEvent["timer"] = "timer";
})(AudioRecordEvent = exports.AudioRecordEvent || (exports.AudioRecordEvent = {}));
const eventsMap = {
    data: AudioRecordEvent.data,
    format: AudioRecordEvent.format,
    timer: AudioRecordEvent.timer,
};
const initRecorder = (options, formatCallback) => {
    recorderOn(AudioRecordEvent.format, formatCallback);
    RNAudioRecord.initialise(options);
};
exports.initRecorder = initRecorder;
const recorderStart = (playbackOptions) => RNAudioRecord.start(playbackOptions);
exports.recorderStart = recorderStart;
const recorderStop = () => RNAudioRecord.stop();
exports.recorderStop = recorderStop;
const recorderOn = (event, callback) => {
    const nativeEvent = eventsMap[event];
    if (!nativeEvent) {
        throw new Error('Invalid event');
    }
    EventEmitter.removeAllListeners(nativeEvent);
    return EventEmitter.addListener(nativeEvent, callback);
};
exports.recorderOn = recorderOn;
//# sourceMappingURL=index.js.map