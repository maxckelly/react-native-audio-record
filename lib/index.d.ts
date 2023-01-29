declare let AudioRecord: any;
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
export default AudioRecord;
