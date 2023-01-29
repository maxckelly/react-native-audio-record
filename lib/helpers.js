"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isNativeModuleLoaded = void 0;
function isNativeModuleLoaded(module) {
    if (module === null) {
        console.error('Could not load RNAudioRecord native module. Make sure native dependencies are properly linked.');
        return false;
    }
    return true;
}
exports.isNativeModuleLoaded = isNativeModuleLoaded;
//# sourceMappingURL=helpers.js.map