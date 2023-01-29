export function isNativeModuleLoaded(module) {
    if (module === null) {
        console.error('Could not load RNAudioRecord native module. Make sure native dependencies are properly linked.');
        return false;
    }
    return true;
}
