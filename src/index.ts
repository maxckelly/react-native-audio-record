import {
  NativeModules,
  NativeEventEmitter,
  EmitterSubscription,
} from 'react-native';
const { RNAudioRecord } = NativeModules;
const EventEmitter = new NativeEventEmitter(RNAudioRecord);

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

const initRecorder = (options: Options, formatCallback:any) => {
  recorderOn(AudioRecordEvent.format, formatCallback);
  RNAudioRecord.initialise(options);
}
const recorderStart = (playbackOptions?: PlaybackOptions): void =>
  RNAudioRecord.start(playbackOptions);
const recorderStop = (): Promise<string> => RNAudioRecord.stop();
const recorderOn = (event: any, callback: any): EmitterSubscription => {
  const nativeEvent = eventsMap[event];
  if (!nativeEvent) {
    throw new Error('Invalid event');
  }
  EventEmitter.removeAllListeners(nativeEvent);
  return EventEmitter.addListener(nativeEvent, callback);
};

export { initRecorder, recorderStart, recorderStop, recorderOn };
