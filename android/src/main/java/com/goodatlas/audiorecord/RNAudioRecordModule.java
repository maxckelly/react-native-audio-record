package com.goodatlas.audiorecord;

import android.annotation.SuppressLint;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder.AudioSource;
import android.media.MediaFormat;
import android.media.MediaCodec;
import android.media.MediaCodecList;
import android.util.Base64;
import android.util.Log;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.react.bridge.Promise;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.Date;
import java.util.Timer;
import java.util.TimerTask;

public class RNAudioRecordModule extends ReactContextBaseJavaModule {
    private final String TAG = "RNAudioRecord";
    private final ReactApplicationContext reactContext;
    private DeviceEventManagerModule.RCTDeviceEventEmitter eventEmitter;

    private int elapsedSeconds = 0;
    private double recordStartTimestamp = 0;
    private double recordStartDuration = 0;

    private Timer timer;

    private AudioRecord recorder;
    private final int audioBufferSize = 10000;

    private MediaCodec codec = null;
    private MediaFormat encodeFormat;

    public RNAudioRecordModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
    }

    private final byte[] audioBufferSynch = new byte[audioBufferSize];


    @Override
    public String getName() {
        return "RNAudioRecord";
    }

    @SuppressLint("MissingPermission")
    @ReactMethod
    public void initialise(ReadableMap options) {
        int sampleRateInHz;
        int channelConfig;
        int numChannels;
        int audioFormat;
        int audioSource;
        String encodeType, encodeFormatName;

        final String OPUS_ENCODE_TYPE = "OPUS";
        final String FLAC_ENCODE_TYPE = "FLAC";
        final String NO_CODEC_AVAILABLE = "NOCODEC";


        Log.d(TAG, "init ");
        sampleRateInHz = 44100;
        if (options.hasKey("sampleRate")) {
            sampleRateInHz = options.getInt("sampleRate");
        }

        channelConfig = AudioFormat.CHANNEL_IN_MONO;
        numChannels = 1;
        if (options.hasKey("channels")) {
            if (options.getInt("channels") == 2) {
                channelConfig = AudioFormat.CHANNEL_IN_STEREO;
                numChannels = 2;
            }
        }

        audioFormat = AudioFormat.ENCODING_PCM_16BIT;
        if (options.hasKey("bitsPerSample")) {
            if (options.getInt("bitsPerSample") == 8) {
                audioFormat = AudioFormat.ENCODING_PCM_8BIT;
            }
        }

        audioSource = AudioSource.VOICE_COMMUNICATION;
        if (options.hasKey("audioSource")) {
            audioSource = options.getInt("audioSource");
        }

        eventEmitter = reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class);

        int recordingBufferSize = audioBufferSize * 3;
        recorder = new AudioRecord(audioSource, sampleRateInHz, channelConfig, audioFormat, recordingBufferSize);

        // set up encoding formats
        MediaFormat opusFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_OPUS, sampleRateInHz, numChannels );
        opusFormat.setInteger(MediaFormat.KEY_BIT_RATE, 30 * 1024);
        MediaFormat flacFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_FLAC, sampleRateInHz, numChannels );
        flacFormat.setInteger(MediaFormat.KEY_BIT_RATE, 30 * 1024);
        MediaCodecList codecList = new MediaCodecList(MediaCodecList.REGULAR_CODECS);

        String opusCodecName = codecList.findEncoderForFormat(opusFormat);
        String flacCodecName = codecList.findEncoderForFormat(flacFormat);

        if (opusCodecName != null) {
            encodeType = OPUS_ENCODE_TYPE;
            encodeFormatName = opusCodecName;
            encodeFormat = opusFormat;
        } else if (flacCodecName != null) {
            encodeType = FLAC_ENCODE_TYPE;
            encodeFormatName = flacCodecName;
            encodeFormat = flacFormat;
        } else {
            eventEmitter.emit("format", NO_CODEC_AVAILABLE);
            return;
        }

        Log.d(TAG, "encodeFormatName " + encodeFormatName);
        Log.d(TAG, "encodeFormat " + encodeFormat);

        try {
            codec = MediaCodec.createByCodecName(encodeFormatName);
        } catch (IOException e) {
            e.printStackTrace();
        }
        eventEmitter.emit("format", encodeType);
    }

    @ReactMethod
    public void start(ReadableMap playbackOptions) {
        recorder.startRecording();
        try {
            setCodecCallbacks();
            codec.configure(encodeFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
        } catch (IllegalArgumentException e) {
            e.printStackTrace();
            Log.d(TAG, e.toString());
        }

        codec.getOutputFormat();
        codec.start();

        timer = new Timer();
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                elapsedSeconds++;
                eventEmitter.emit("timer", Integer.toString(elapsedSeconds));
            }
        }, 1000, 1000);

        recordStartDuration = playbackOptions.getDouble("elapsedSeconds");
        elapsedSeconds = (int)Math.round(recordStartDuration);
        recordStartTimestamp = now();
    }

    private double now() {
        return new Date().getTime();
    }

    @ReactMethod
    public void stop(Promise promise) {
        recorder.stop();
        codec.stop();
        codec.reset();
        timer.cancel();
        timer = null;
        double recordFinishDuration = recordStartDuration + ((now() - recordStartTimestamp)/1000);
        promise.resolve(String.valueOf(Math.round(recordFinishDuration * 10) / 10.0));
    }

    private String toBase64String(ByteBuffer buff) {
        ByteBuffer bb = buff.asReadOnlyBuffer();
        bb.position(0);
        byte[] b = new byte[bb.limit()];
        bb.get(b, 0, b.length);
        return new String(Base64.encode(b, Base64.DEFAULT));
    }

    private void setCodecCallbacks() {
        codec.setCallback(new MediaCodec.Callback() {
            @Override
            public void onInputBufferAvailable(MediaCodec mc, int inputBufferId) {
                ByteBuffer inputBuffer = codec.getInputBuffer(inputBufferId);
                int bufferLimit = inputBuffer.limit();
                int bytesRead = recorder.read(audioBufferSynch, 0, bufferLimit);
                inputBuffer.put(audioBufferSynch, 0, bytesRead);
                codec.queueInputBuffer(inputBufferId,
                        0,
                        bytesRead,
                        0,
                        0);
            }

            @Override
            public void onOutputBufferAvailable(@NonNull MediaCodec mediaCodec, int outputBufferId, @NonNull MediaCodec.BufferInfo bufferInfo) {
                ByteBuffer outputBuffer = codec.getOutputBuffer(outputBufferId);
                String dataString = toBase64String(outputBuffer);
                codec.releaseOutputBuffer(outputBufferId, false);
                eventEmitter.emit("data", dataString);
            }

            @Override
            public void onError(@NonNull MediaCodec mediaCodec, @NonNull MediaCodec.CodecException e) {
                e.printStackTrace();
                Log.d(TAG, "onError " + e);
            }

            @Override
            public void onOutputFormatChanged(MediaCodec mc, MediaFormat format) {
                // Subsequent data will conform to new format.
                // Can ignore if using getOutputFormat(outputBufferId)
                // mOutputFormat = format; // option B
            }
        });
    }
}
