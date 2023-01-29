import { EmitterSubscription } from 'react-native';
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
export declare enum AudioRecordEvent {
    data = "data",
    format = "format",
    timer = "timer"
}
export interface PlaybackOptions {
    allowHaptics?: boolean;
    elapsedSeconds: number;
}
declare const initRecorder: (options: Options, formatCallback: any) => void;
declare const recorderStart: (playbackOptions?: PlaybackOptions) => void;
declare const recorderStop: () => Promise<string>;
declare const recorderOn: (event: any, callback: any) => EmitterSubscription;
export { initRecorder, recorderStart, recorderStop, recorderOn };
