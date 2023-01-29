import {
  NativeModules,
  NativeEventEmitter,
  EmitterSubscription,
} from 'react-native';
import { isNativeModuleLoaded } from './helpers';
const { RNAudioRecord } = NativeModules;
let EventEmitter: NativeEventEmitter;
let AudioRecord: any;

if (isNativeModuleLoaded(RNAudioRecord)) {
  EventEmitter = new NativeEventEmitter(RNAudioRecord);
}

export interface Options {
  sampleRate: number;
  /**
   * - `1 | 2`
   */
  channels: number;
  /**
   * - `8 | 16`
   */
  bitsPerSample: number;
  /**
   * - `6`
   */
  audioSource?: number;
}

export enum AudioRecordEvent {
  data = 'data',
  format = 'format',
  timer = 'timer',
}

const eventsMap: any = {
  data: AudioRecordEvent.data,
  format: AudioRecordEvent.format,
  timer: AudioRecordEvent.timer,
};

export interface PlaybackOptions {
  allowHaptics?: boolean;
  elapsedSeconds: number;
}

AudioRecord.recorderOn = (event: any, callback: any): EmitterSubscription => {
  const nativeEvent = eventsMap[event];
  if (!nativeEvent) {
    throw new Error('Invalid event');
  }
  EventEmitter.removeAllListeners(nativeEvent);
  return EventEmitter.addListener(nativeEvent, callback);
};

AudioRecord.initRecorder = (options: Options, formatCallback: any) => {
  AudioRecord.recorderOn(AudioRecordEvent.format, formatCallback);
  RNAudioRecord.initialise(options);
};

AudioRecord.recorderStart = (playbackOptions?: PlaybackOptions): void =>
  RNAudioRecord.start(playbackOptions);

AudioRecord.recorderStop = (): Promise<string> => RNAudioRecord.stop();

export default AudioRecord;
