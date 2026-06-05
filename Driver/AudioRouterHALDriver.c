#include <CoreAudio/AudioHardware.h>
#include <CoreAudio/AudioServerPlugIn.h>
#include <CoreFoundation/CoreFoundation.h>
#include <fcntl.h>
#include <mach/mach_time.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

enum {
    kAudioRouterDeviceObjectID = 2,
    kAudioRouterInputStreamObjectID = 3
};

static const Float64 kAudioRouterSampleRate = 48000.0;
static const UInt32 kAudioRouterChannelCount = 2;
static const UInt32 kAudioRouterBytesPerSample = sizeof(Float32);
static const UInt32 kAudioRouterBufferFrameSize = 512;

#define AUDIO_ROUTER_SHM_PATH "/tmp/AudioRouterHALInputV1.buffer"
#define AUDIO_ROUTER_SHM_MAGIC 0x41524931u
#define AUDIO_ROUTER_SHM_VERSION 1u
#define AUDIO_ROUTER_SHM_FRAME_CAPACITY 96000u

typedef struct AudioRouterSharedInputHeader {
    uint32_t magic;
    uint32_t version;
    uint32_t channelCount;
    uint32_t sampleRate;
    uint32_t frameCapacity;
    uint32_t reserved;
    volatile uint64_t writeFrame;
} AudioRouterSharedInputHeader;

static AudioServerPlugInHostRef gHost = NULL;
static UInt32 gRefCount = 1;
static UInt32 gRunningClientCount = 0;
static UInt64 gStartHostTime = 0;
static UInt64 gTimeStampSeed = 1;
static AudioRouterSharedInputHeader* gSharedInput = NULL;
static Float32* gSharedInputSamples = NULL;
static size_t gSharedInputByteSize = 0;
static uint64_t gSharedInputReadFrame = 0;

static void AudioRouterMapSharedInput(void) {
    if (gSharedInput != NULL) {
        return;
    }

    gSharedInputByteSize = sizeof(AudioRouterSharedInputHeader)
        + ((size_t)AUDIO_ROUTER_SHM_FRAME_CAPACITY * kAudioRouterChannelCount * sizeof(Float32));
    int fd = open(AUDIO_ROUTER_SHM_PATH, O_CREAT | O_RDWR, 0666);
    if (fd < 0) {
        return;
    }
    if (ftruncate(fd, (off_t)gSharedInputByteSize) != 0) {
        close(fd);
        return;
    }

    void* mapping = mmap(NULL, gSharedInputByteSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    if (mapping == MAP_FAILED) {
        return;
    }

    gSharedInput = (AudioRouterSharedInputHeader*)mapping;
    gSharedInputSamples = (Float32*)((uint8_t*)mapping + sizeof(AudioRouterSharedInputHeader));
    if (gSharedInput->magic != AUDIO_ROUTER_SHM_MAGIC
        || gSharedInput->version != AUDIO_ROUTER_SHM_VERSION
        || gSharedInput->channelCount != kAudioRouterChannelCount
        || gSharedInput->frameCapacity != AUDIO_ROUTER_SHM_FRAME_CAPACITY) {
        memset(mapping, 0, gSharedInputByteSize);
        gSharedInput->magic = AUDIO_ROUTER_SHM_MAGIC;
        gSharedInput->version = AUDIO_ROUTER_SHM_VERSION;
        gSharedInput->channelCount = kAudioRouterChannelCount;
        gSharedInput->sampleRate = (uint32_t)kAudioRouterSampleRate;
        gSharedInput->frameCapacity = AUDIO_ROUTER_SHM_FRAME_CAPACITY;
        gSharedInput->writeFrame = 0;
    }
    gSharedInputReadFrame = gSharedInput->writeFrame;
}

static AudioStreamBasicDescription AudioRouterStreamFormat(void) {
    AudioStreamBasicDescription format;
    memset(&format, 0, sizeof(format));
    format.mSampleRate = kAudioRouterSampleRate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
    format.mBytesPerPacket = kAudioRouterChannelCount * kAudioRouterBytesPerSample;
    format.mFramesPerPacket = 1;
    format.mBytesPerFrame = kAudioRouterChannelCount * kAudioRouterBytesPerSample;
    format.mChannelsPerFrame = kAudioRouterChannelCount;
    format.mBitsPerChannel = kAudioRouterBytesPerSample * 8;
    return format;
}

static AudioStreamRangedDescription AudioRouterRangedFormat(void) {
    AudioStreamRangedDescription range;
    memset(&range, 0, sizeof(range));
    range.mFormat = AudioRouterStreamFormat();
    range.mSampleRateRange.mMinimum = kAudioRouterSampleRate;
    range.mSampleRateRange.mMaximum = kAudioRouterSampleRate;
    return range;
}

static Boolean AudioRouterUUIDsEqual(CFUUIDRef lhs, CFUUIDBytes rhs) {
    CFUUIDBytes lhsBytes = CFUUIDGetUUIDBytes(lhs);
    return memcmp(&lhsBytes, &rhs, sizeof(CFUUIDBytes)) == 0;
}

static Boolean AudioRouterIsKnownObject(AudioObjectID objectID) {
    return objectID == kAudioObjectPlugInObject
        || objectID == kAudioRouterDeviceObjectID
        || objectID == kAudioRouterInputStreamObjectID;
}

static AudioClassID AudioRouterClassForObject(AudioObjectID objectID) {
    switch (objectID) {
    case kAudioObjectPlugInObject: return kAudioPlugInClassID;
    case kAudioRouterDeviceObjectID: return kAudioDeviceClassID;
    case kAudioRouterInputStreamObjectID: return kAudioStreamClassID;
    default: return kAudioObjectClassID;
    }
}

static AudioObjectID AudioRouterOwnerForObject(AudioObjectID objectID) {
    switch (objectID) {
    case kAudioObjectPlugInObject: return kAudioObjectUnknown;
    case kAudioRouterDeviceObjectID: return kAudioObjectPlugInObject;
    case kAudioRouterInputStreamObjectID: return kAudioRouterDeviceObjectID;
    default: return kAudioObjectUnknown;
    }
}

static Boolean AudioRouterIsInputScope(AudioObjectPropertyScope scope) {
    return scope == kAudioObjectPropertyScopeInput
        || scope == kAudioObjectPropertyScopeGlobal
        || scope == kAudioObjectPropertyScopeWildcard;
}

static Boolean AudioRouterIsOutputScope(AudioObjectPropertyScope scope) {
    return scope == kAudioObjectPropertyScopeOutput;
}

static UInt32 AudioRouterBufferListSize(UInt32 bufferCount) {
    return (UInt32)(offsetof(AudioBufferList, mBuffers) + (bufferCount * sizeof(AudioBuffer)));
}

static OSStatus AudioRouterCopyCFString(CFStringRef value, UInt32 inDataSize, UInt32* outDataSize, void* outData) {
    if (inDataSize < sizeof(CFStringRef)) {
        return kAudioHardwareBadPropertySizeError;
    }
    CFRetain(value);
    *((CFStringRef*)outData) = value;
    *outDataSize = sizeof(CFStringRef);
    return kAudioHardwareNoError;
}

static OSStatus AudioRouterCopyUInt32(UInt32 value, UInt32 inDataSize, UInt32* outDataSize, void* outData) {
    if (inDataSize < sizeof(UInt32)) {
        return kAudioHardwareBadPropertySizeError;
    }
    *((UInt32*)outData) = value;
    *outDataSize = sizeof(UInt32);
    return kAudioHardwareNoError;
}

static OSStatus AudioRouterCopyFloat64(Float64 value, UInt32 inDataSize, UInt32* outDataSize, void* outData) {
    if (inDataSize < sizeof(Float64)) {
        return kAudioHardwareBadPropertySizeError;
    }
    *((Float64*)outData) = value;
    *outDataSize = sizeof(Float64);
    return kAudioHardwareNoError;
}

static OSStatus AudioRouterCopyObjectID(AudioObjectID value, UInt32 inDataSize, UInt32* outDataSize, void* outData) {
    if (inDataSize < sizeof(AudioObjectID)) {
        return kAudioHardwareBadPropertySizeError;
    }
    *((AudioObjectID*)outData) = value;
    *outDataSize = sizeof(AudioObjectID);
    return kAudioHardwareNoError;
}

static Boolean AudioRouterHasProperty(
    AudioServerPlugInDriverRef inDriver,
    AudioObjectID inObjectID,
    pid_t inClientProcessID,
    const AudioObjectPropertyAddress* inAddress
);
static OSStatus AudioRouterIsPropertySettable(
    AudioServerPlugInDriverRef inDriver,
    AudioObjectID inObjectID,
    pid_t inClientProcessID,
    const AudioObjectPropertyAddress* inAddress,
    Boolean* outIsSettable
);
static OSStatus AudioRouterGetPropertyDataSize(
    AudioServerPlugInDriverRef inDriver,
    AudioObjectID inObjectID,
    pid_t inClientProcessID,
    const AudioObjectPropertyAddress* inAddress,
    UInt32 inQualifierDataSize,
    const void* inQualifierData,
    UInt32* outDataSize
);
static OSStatus AudioRouterGetPropertyData(
    AudioServerPlugInDriverRef inDriver,
    AudioObjectID inObjectID,
    pid_t inClientProcessID,
    const AudioObjectPropertyAddress* inAddress,
    UInt32 inQualifierDataSize,
    const void* inQualifierData,
    UInt32 inDataSize,
    UInt32* outDataSize,
    void* outData
);
static OSStatus AudioRouterSetPropertyData(
    AudioServerPlugInDriverRef inDriver,
    AudioObjectID inObjectID,
    pid_t inClientProcessID,
    const AudioObjectPropertyAddress* inAddress,
    UInt32 inQualifierDataSize,
    const void* inQualifierData,
    UInt32 inDataSize,
    const void* inData
);

static HRESULT STDMETHODCALLTYPE AudioRouterQueryInterface(void* inDriver, REFIID inUUID, LPVOID* outInterface);
static ULONG STDMETHODCALLTYPE AudioRouterAddRef(void* inDriver);
static ULONG STDMETHODCALLTYPE AudioRouterRelease(void* inDriver);
static OSStatus AudioRouterInitialize(AudioServerPlugInDriverRef inDriver, AudioServerPlugInHostRef inHost);
static OSStatus AudioRouterCreateDevice(AudioServerPlugInDriverRef inDriver, CFDictionaryRef inDescription, const AudioServerPlugInClientInfo* inClientInfo, AudioObjectID* outDeviceObjectID);
static OSStatus AudioRouterDestroyDevice(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID);
static OSStatus AudioRouterAddDeviceClient(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, const AudioServerPlugInClientInfo* inClientInfo);
static OSStatus AudioRouterRemoveDeviceClient(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, const AudioServerPlugInClientInfo* inClientInfo);
static OSStatus AudioRouterPerformDeviceConfigurationChange(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt64 inChangeAction, void* inChangeInfo);
static OSStatus AudioRouterAbortDeviceConfigurationChange(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt64 inChangeAction, void* inChangeInfo);
static OSStatus AudioRouterStartIO(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID);
static OSStatus AudioRouterStopIO(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID);
static OSStatus AudioRouterGetZeroTimeStamp(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, Float64* outSampleTime, UInt64* outHostTime, UInt64* outSeed);
static OSStatus AudioRouterWillDoIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, UInt32 inOperationID, Boolean* outWillDo, Boolean* outWillDoInPlace);
static OSStatus AudioRouterBeginIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, UInt32 inOperationID, UInt32 inIOBufferFrameSize, const AudioServerPlugInIOCycleInfo* inIOCycleInfo);
static OSStatus AudioRouterDoIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, AudioObjectID inStreamObjectID, UInt32 inClientID, UInt32 inOperationID, UInt32 inIOBufferFrameSize, const AudioServerPlugInIOCycleInfo* inIOCycleInfo, void* ioMainBuffer, void* ioSecondaryBuffer);
static OSStatus AudioRouterEndIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, UInt32 inOperationID, UInt32 inIOBufferFrameSize, const AudioServerPlugInIOCycleInfo* inIOCycleInfo);

static AudioServerPlugInDriverInterface gDriverInterface = {
    NULL,
    AudioRouterQueryInterface,
    AudioRouterAddRef,
    AudioRouterRelease,
    AudioRouterInitialize,
    AudioRouterCreateDevice,
    AudioRouterDestroyDevice,
    AudioRouterAddDeviceClient,
    AudioRouterRemoveDeviceClient,
    AudioRouterPerformDeviceConfigurationChange,
    AudioRouterAbortDeviceConfigurationChange,
    AudioRouterHasProperty,
    AudioRouterIsPropertySettable,
    AudioRouterGetPropertyDataSize,
    AudioRouterGetPropertyData,
    AudioRouterSetPropertyData,
    AudioRouterStartIO,
    AudioRouterStopIO,
    AudioRouterGetZeroTimeStamp,
    AudioRouterWillDoIOOperation,
    AudioRouterBeginIOOperation,
    AudioRouterDoIOOperation,
    AudioRouterEndIOOperation
};

static AudioServerPlugInDriverInterface* gDriverInterfacePtr = &gDriverInterface;

__attribute__((visibility("default")))
void* AudioRouterPlugInFactory(CFAllocatorRef allocator, CFUUIDRef requestedTypeUUID) {
    if (AudioRouterUUIDsEqual(requestedTypeUUID, CFUUIDGetUUIDBytes(kAudioServerPlugInTypeUUID))) {
        AudioRouterAddRef(&gDriverInterfacePtr);
        return &gDriverInterfacePtr;
    }
    return NULL;
}

static HRESULT STDMETHODCALLTYPE AudioRouterQueryInterface(void* inDriver, REFIID inUUID, LPVOID* outInterface) {
    if (outInterface == NULL) {
        return E_POINTER;
    }
    CFUUIDRef requestedUUID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, inUUID);
    if (requestedUUID == NULL) {
        *outInterface = NULL;
        return E_NOINTERFACE;
    }
    Boolean matchesIUnknown = CFEqual(requestedUUID, IUnknownUUID);
    Boolean matchesDriver = CFEqual(requestedUUID, kAudioServerPlugInDriverInterfaceUUID);
    CFRelease(requestedUUID);
    if (matchesIUnknown || matchesDriver) {
        AudioRouterAddRef(inDriver);
        *outInterface = &gDriverInterfacePtr;
        return S_OK;
    }
    *outInterface = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE AudioRouterAddRef(void* inDriver) {
    return __sync_add_and_fetch(&gRefCount, 1);
}

static ULONG STDMETHODCALLTYPE AudioRouterRelease(void* inDriver) {
    UInt32 count = __sync_sub_and_fetch(&gRefCount, 1);
    return count;
}

static OSStatus AudioRouterInitialize(AudioServerPlugInDriverRef inDriver, AudioServerPlugInHostRef inHost) {
    gHost = inHost;
    gStartHostTime = mach_absolute_time();
    AudioRouterMapSharedInput();
    return kAudioHardwareNoError;
}

static OSStatus AudioRouterCreateDevice(AudioServerPlugInDriverRef inDriver, CFDictionaryRef inDescription, const AudioServerPlugInClientInfo* inClientInfo, AudioObjectID* outDeviceObjectID) {
    if (outDeviceObjectID != NULL) {
        *outDeviceObjectID = kAudioObjectUnknown;
    }
    return kAudioHardwareUnsupportedOperationError;
}

static OSStatus AudioRouterDestroyDevice(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID) {
    return kAudioHardwareUnsupportedOperationError;
}

static OSStatus AudioRouterAddDeviceClient(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, const AudioServerPlugInClientInfo* inClientInfo) {
    return inDeviceObjectID == kAudioRouterDeviceObjectID ? kAudioHardwareNoError : kAudioHardwareBadDeviceError;
}

static OSStatus AudioRouterRemoveDeviceClient(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, const AudioServerPlugInClientInfo* inClientInfo) {
    return inDeviceObjectID == kAudioRouterDeviceObjectID ? kAudioHardwareNoError : kAudioHardwareBadDeviceError;
}

static OSStatus AudioRouterPerformDeviceConfigurationChange(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt64 inChangeAction, void* inChangeInfo) {
    return kAudioHardwareNoError;
}

static OSStatus AudioRouterAbortDeviceConfigurationChange(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt64 inChangeAction, void* inChangeInfo) {
    return kAudioHardwareNoError;
}

static Boolean AudioRouterHasProperty(
    AudioServerPlugInDriverRef inDriver,
    AudioObjectID inObjectID,
    pid_t inClientProcessID,
    const AudioObjectPropertyAddress* inAddress
) {
    if (inAddress == NULL || !AudioRouterIsKnownObject(inObjectID)) {
        return false;
    }

    switch (inAddress->mSelector) {
    case kAudioObjectPropertyBaseClass:
    case kAudioObjectPropertyClass:
    case kAudioObjectPropertyOwner:
    case kAudioObjectPropertyName:
    case kAudioObjectPropertyModelName:
    case kAudioObjectPropertyManufacturer:
    case kAudioObjectPropertyOwnedObjects:
        return true;
    default:
        break;
    }

    if (inObjectID == kAudioObjectPlugInObject) {
        switch (inAddress->mSelector) {
        case kAudioPlugInPropertyBundleID:
        case kAudioPlugInPropertyDeviceList:
        case kAudioPlugInPropertyTranslateUIDToDevice:
        case kAudioPlugInPropertyBoxList:
        case kAudioPlugInPropertyClockDeviceList:
            return true;
        default:
            return false;
        }
    }

    if (inObjectID == kAudioRouterDeviceObjectID) {
        switch (inAddress->mSelector) {
        case kAudioDevicePropertyDeviceUID:
        case kAudioDevicePropertyModelUID:
        case kAudioDevicePropertyTransportType:
        case kAudioDevicePropertyRelatedDevices:
        case kAudioDevicePropertyClockDomain:
        case kAudioDevicePropertyDeviceIsAlive:
        case kAudioDevicePropertyDeviceIsRunning:
        case kAudioDevicePropertyDeviceIsRunningSomewhere:
        case kAudioDevicePropertyDeviceCanBeDefaultDevice:
        case kAudioDevicePropertyDeviceCanBeDefaultSystemDevice:
        case kAudioDevicePropertyLatency:
        case kAudioDevicePropertyStreams:
        case kAudioObjectPropertyControlList:
        case kAudioDevicePropertySafetyOffset:
        case kAudioDevicePropertyNominalSampleRate:
        case kAudioDevicePropertyAvailableNominalSampleRates:
        case kAudioDevicePropertyIsHidden:
        case kAudioDevicePropertyPreferredChannelsForStereo:
        case kAudioDevicePropertyStreamConfiguration:
        case kAudioDevicePropertyBufferFrameSize:
        case kAudioDevicePropertyBufferFrameSizeRange:
        case kAudioDevicePropertyUsesVariableBufferFrameSizes:
        case kAudioDevicePropertyIOCycleUsage:
        case kAudioDevicePropertyActualSampleRate:
        case kAudioDevicePropertyZeroTimeStampPeriod:
            return true;
        default:
            return false;
        }
    }

    if (inObjectID == kAudioRouterInputStreamObjectID) {
        switch (inAddress->mSelector) {
        case kAudioStreamPropertyIsActive:
        case kAudioStreamPropertyDirection:
        case kAudioStreamPropertyTerminalType:
        case kAudioStreamPropertyStartingChannel:
        case kAudioStreamPropertyLatency:
        case kAudioStreamPropertyVirtualFormat:
        case kAudioStreamPropertyAvailableVirtualFormats:
        case kAudioStreamPropertyPhysicalFormat:
        case kAudioStreamPropertyAvailablePhysicalFormats:
            return true;
        default:
            return false;
        }
    }

    return false;
}

static OSStatus AudioRouterIsPropertySettable(
    AudioServerPlugInDriverRef inDriver,
    AudioObjectID inObjectID,
    pid_t inClientProcessID,
    const AudioObjectPropertyAddress* inAddress,
    Boolean* outIsSettable
) {
    if (outIsSettable == NULL) {
        return kAudioHardwareIllegalOperationError;
    }
    if (!AudioRouterHasProperty(inDriver, inObjectID, inClientProcessID, inAddress)) {
        return kAudioHardwareUnknownPropertyError;
    }
    *outIsSettable = false;
    if (inObjectID == kAudioRouterDeviceObjectID && inAddress->mSelector == kAudioDevicePropertyBufferFrameSize) {
        *outIsSettable = true;
    }
    return kAudioHardwareNoError;
}

static OSStatus AudioRouterGetPropertyDataSize(
    AudioServerPlugInDriverRef inDriver,
    AudioObjectID inObjectID,
    pid_t inClientProcessID,
    const AudioObjectPropertyAddress* inAddress,
    UInt32 inQualifierDataSize,
    const void* inQualifierData,
    UInt32* outDataSize
) {
    if (outDataSize == NULL || !AudioRouterHasProperty(inDriver, inObjectID, inClientProcessID, inAddress)) {
        return kAudioHardwareUnknownPropertyError;
    }

    switch (inAddress->mSelector) {
    case kAudioObjectPropertyBaseClass:
    case kAudioObjectPropertyClass:
    case kAudioObjectPropertyOwner:
    case kAudioDevicePropertyTransportType:
    case kAudioDevicePropertyClockDomain:
    case kAudioDevicePropertyDeviceIsAlive:
    case kAudioDevicePropertyDeviceIsRunning:
    case kAudioDevicePropertyDeviceIsRunningSomewhere:
    case kAudioDevicePropertyDeviceCanBeDefaultDevice:
    case kAudioDevicePropertyDeviceCanBeDefaultSystemDevice:
    case kAudioDevicePropertyLatency:
    case kAudioDevicePropertySafetyOffset:
    case kAudioDevicePropertyIsHidden:
    case kAudioDevicePropertyBufferFrameSize:
    case kAudioDevicePropertyUsesVariableBufferFrameSizes:
    case kAudioDevicePropertyIOCycleUsage:
    case kAudioDevicePropertyZeroTimeStampPeriod:
    case kAudioStreamPropertyIsActive:
    case kAudioStreamPropertyDirection:
    case kAudioStreamPropertyTerminalType:
    case kAudioStreamPropertyStartingChannel:
        *outDataSize = sizeof(UInt32);
        return kAudioHardwareNoError;
    case kAudioObjectPropertyName:
    case kAudioObjectPropertyModelName:
    case kAudioObjectPropertyManufacturer:
    case kAudioPlugInPropertyBundleID:
    case kAudioDevicePropertyDeviceUID:
    case kAudioDevicePropertyModelUID:
        *outDataSize = sizeof(CFStringRef);
        return kAudioHardwareNoError;
    case kAudioPlugInPropertyDeviceList:
    case kAudioObjectPropertyOwnedObjects:
        *outDataSize = (inObjectID == kAudioRouterInputStreamObjectID) ? 0 : sizeof(AudioObjectID);
        return kAudioHardwareNoError;
    case kAudioPlugInPropertyTranslateUIDToDevice:
        *outDataSize = sizeof(AudioObjectID);
        return kAudioHardwareNoError;
    case kAudioPlugInPropertyBoxList:
    case kAudioPlugInPropertyClockDeviceList:
    case kAudioDevicePropertyRelatedDevices:
    case kAudioObjectPropertyControlList:
        *outDataSize = 0;
        return kAudioHardwareNoError;
    case kAudioDevicePropertyStreams:
        *outDataSize = AudioRouterIsOutputScope(inAddress->mScope) ? 0 : sizeof(AudioObjectID);
        return kAudioHardwareNoError;
    case kAudioDevicePropertyNominalSampleRate:
    case kAudioDevicePropertyActualSampleRate:
        *outDataSize = sizeof(Float64);
        return kAudioHardwareNoError;
    case kAudioDevicePropertyAvailableNominalSampleRates:
        *outDataSize = sizeof(AudioValueRange);
        return kAudioHardwareNoError;
    case kAudioDevicePropertyPreferredChannelsForStereo:
        *outDataSize = 2 * sizeof(UInt32);
        return kAudioHardwareNoError;
    case kAudioDevicePropertyStreamConfiguration:
        *outDataSize = AudioRouterBufferListSize(AudioRouterIsInputScope(inAddress->mScope) ? 1 : 0);
        return kAudioHardwareNoError;
    case kAudioDevicePropertyBufferFrameSizeRange:
        *outDataSize = sizeof(AudioValueRange);
        return kAudioHardwareNoError;
    case kAudioStreamPropertyVirtualFormat:
    case kAudioStreamPropertyPhysicalFormat:
        *outDataSize = sizeof(AudioStreamBasicDescription);
        return kAudioHardwareNoError;
    case kAudioStreamPropertyAvailableVirtualFormats:
    case kAudioStreamPropertyAvailablePhysicalFormats:
        *outDataSize = sizeof(AudioStreamRangedDescription);
        return kAudioHardwareNoError;
    default:
        return kAudioHardwareUnknownPropertyError;
    }
}

static OSStatus AudioRouterGetPropertyData(
    AudioServerPlugInDriverRef inDriver,
    AudioObjectID inObjectID,
    pid_t inClientProcessID,
    const AudioObjectPropertyAddress* inAddress,
    UInt32 inQualifierDataSize,
    const void* inQualifierData,
    UInt32 inDataSize,
    UInt32* outDataSize,
    void* outData
) {
    if (outDataSize == NULL || outData == NULL) {
        return kAudioHardwareIllegalOperationError;
    }
    if (!AudioRouterHasProperty(inDriver, inObjectID, inClientProcessID, inAddress)) {
        return kAudioHardwareUnknownPropertyError;
    }

    switch (inAddress->mSelector) {
    case kAudioObjectPropertyBaseClass:
        return AudioRouterCopyUInt32(AudioRouterClassForObject(inObjectID), inDataSize, outDataSize, outData);
    case kAudioObjectPropertyClass:
        return AudioRouterCopyUInt32(AudioRouterClassForObject(inObjectID), inDataSize, outDataSize, outData);
    case kAudioObjectPropertyOwner:
        return AudioRouterCopyObjectID(AudioRouterOwnerForObject(inObjectID), inDataSize, outDataSize, outData);
    case kAudioObjectPropertyName:
        if (inObjectID == kAudioObjectPlugInObject) return AudioRouterCopyCFString(CFSTR("AudioRouter HAL Driver"), inDataSize, outDataSize, outData);
        if (inObjectID == kAudioRouterDeviceObjectID) return AudioRouterCopyCFString(CFSTR("AudioRouter Virtual Input"), inDataSize, outDataSize, outData);
        return AudioRouterCopyCFString(CFSTR("AudioRouter App Stream"), inDataSize, outDataSize, outData);
    case kAudioObjectPropertyModelName:
        return AudioRouterCopyCFString(CFSTR("AudioRouter Virtual Input"), inDataSize, outDataSize, outData);
    case kAudioObjectPropertyManufacturer:
        return AudioRouterCopyCFString(CFSTR("Alan"), inDataSize, outDataSize, outData);
    case kAudioObjectPropertyOwnedObjects:
        if (inObjectID == kAudioObjectPlugInObject) {
            return AudioRouterCopyObjectID(kAudioRouterDeviceObjectID, inDataSize, outDataSize, outData);
        }
        if (inObjectID == kAudioRouterDeviceObjectID) {
            return AudioRouterCopyObjectID(kAudioRouterInputStreamObjectID, inDataSize, outDataSize, outData);
        }
        *outDataSize = 0;
        return kAudioHardwareNoError;
    case kAudioPlugInPropertyBundleID:
        return AudioRouterCopyCFString(CFSTR("com.local.AudioRouter.HALDriver"), inDataSize, outDataSize, outData);
    case kAudioPlugInPropertyDeviceList:
        return AudioRouterCopyObjectID(kAudioRouterDeviceObjectID, inDataSize, outDataSize, outData);
    case kAudioPlugInPropertyTranslateUIDToDevice: {
        AudioObjectID deviceID = kAudioObjectUnknown;
        if (inQualifierDataSize == sizeof(CFStringRef) && inQualifierData != NULL) {
            CFStringRef uid = *((CFStringRef*)inQualifierData);
            if (uid != NULL && CFStringCompare(uid, CFSTR("com.local.AudioRouter.driver.input"), 0) == kCFCompareEqualTo) {
                deviceID = kAudioRouterDeviceObjectID;
            }
        }
        return AudioRouterCopyObjectID(deviceID, inDataSize, outDataSize, outData);
    }
    case kAudioPlugInPropertyBoxList:
    case kAudioPlugInPropertyClockDeviceList:
    case kAudioDevicePropertyRelatedDevices:
    case kAudioObjectPropertyControlList:
        *outDataSize = 0;
        return kAudioHardwareNoError;
    case kAudioDevicePropertyDeviceUID:
        return AudioRouterCopyCFString(CFSTR("com.local.AudioRouter.driver.input"), inDataSize, outDataSize, outData);
    case kAudioDevicePropertyModelUID:
        return AudioRouterCopyCFString(CFSTR("com.local.AudioRouter.driver.model.input"), inDataSize, outDataSize, outData);
    case kAudioDevicePropertyTransportType:
        return AudioRouterCopyUInt32(kAudioDeviceTransportTypeVirtual, inDataSize, outDataSize, outData);
    case kAudioDevicePropertyClockDomain:
    case kAudioDevicePropertyLatency:
    case kAudioDevicePropertySafetyOffset:
    case kAudioDevicePropertyUsesVariableBufferFrameSizes:
    case kAudioDevicePropertyIOCycleUsage:
        return AudioRouterCopyUInt32(0, inDataSize, outDataSize, outData);
    case kAudioDevicePropertyDeviceIsAlive:
        return AudioRouterCopyUInt32(1, inDataSize, outDataSize, outData);
    case kAudioDevicePropertyDeviceIsRunning:
    case kAudioDevicePropertyDeviceIsRunningSomewhere:
        return AudioRouterCopyUInt32(gRunningClientCount > 0 ? 1 : 0, inDataSize, outDataSize, outData);
    case kAudioDevicePropertyDeviceCanBeDefaultDevice:
        return AudioRouterCopyUInt32(AudioRouterIsInputScope(inAddress->mScope) ? 1 : 0, inDataSize, outDataSize, outData);
    case kAudioDevicePropertyDeviceCanBeDefaultSystemDevice:
        return AudioRouterCopyUInt32(0, inDataSize, outDataSize, outData);
    case kAudioDevicePropertyStreams:
        if (AudioRouterIsOutputScope(inAddress->mScope)) {
            *outDataSize = 0;
            return kAudioHardwareNoError;
        }
        return AudioRouterCopyObjectID(kAudioRouterInputStreamObjectID, inDataSize, outDataSize, outData);
    case kAudioDevicePropertyNominalSampleRate:
    case kAudioDevicePropertyActualSampleRate:
        return AudioRouterCopyFloat64(kAudioRouterSampleRate, inDataSize, outDataSize, outData);
    case kAudioDevicePropertyAvailableNominalSampleRates: {
        if (inDataSize < sizeof(AudioValueRange)) return kAudioHardwareBadPropertySizeError;
        AudioValueRange range = { kAudioRouterSampleRate, kAudioRouterSampleRate };
        *((AudioValueRange*)outData) = range;
        *outDataSize = sizeof(AudioValueRange);
        return kAudioHardwareNoError;
    }
    case kAudioDevicePropertyIsHidden:
        return AudioRouterCopyUInt32(0, inDataSize, outDataSize, outData);
    case kAudioDevicePropertyPreferredChannelsForStereo:
        if (inDataSize < 2 * sizeof(UInt32)) return kAudioHardwareBadPropertySizeError;
        ((UInt32*)outData)[0] = 1;
        ((UInt32*)outData)[1] = 2;
        *outDataSize = 2 * sizeof(UInt32);
        return kAudioHardwareNoError;
    case kAudioDevicePropertyStreamConfiguration: {
        UInt32 bufferCount = AudioRouterIsInputScope(inAddress->mScope) ? 1 : 0;
        UInt32 requiredSize = AudioRouterBufferListSize(bufferCount);
        if (inDataSize < requiredSize) return kAudioHardwareBadPropertySizeError;
        AudioBufferList* bufferList = (AudioBufferList*)outData;
        bufferList->mNumberBuffers = bufferCount;
        if (bufferCount == 1) {
            bufferList->mBuffers[0].mNumberChannels = kAudioRouterChannelCount;
            bufferList->mBuffers[0].mDataByteSize = 0;
            bufferList->mBuffers[0].mData = NULL;
        }
        *outDataSize = requiredSize;
        return kAudioHardwareNoError;
    }
    case kAudioDevicePropertyBufferFrameSize:
    case kAudioDevicePropertyZeroTimeStampPeriod:
        return AudioRouterCopyUInt32(kAudioRouterBufferFrameSize, inDataSize, outDataSize, outData);
    case kAudioDevicePropertyBufferFrameSizeRange: {
        if (inDataSize < sizeof(AudioValueRange)) return kAudioHardwareBadPropertySizeError;
        AudioValueRange range = { 64, 4096 };
        *((AudioValueRange*)outData) = range;
        *outDataSize = sizeof(AudioValueRange);
        return kAudioHardwareNoError;
    }
    case kAudioStreamPropertyIsActive:
        return AudioRouterCopyUInt32(1, inDataSize, outDataSize, outData);
    case kAudioStreamPropertyDirection:
        return AudioRouterCopyUInt32(1, inDataSize, outDataSize, outData);
    case kAudioStreamPropertyTerminalType:
        return AudioRouterCopyUInt32(kAudioStreamTerminalTypeMicrophone, inDataSize, outDataSize, outData);
    case kAudioStreamPropertyStartingChannel:
        return AudioRouterCopyUInt32(1, inDataSize, outDataSize, outData);
    case kAudioStreamPropertyVirtualFormat:
    case kAudioStreamPropertyPhysicalFormat:
        if (inDataSize < sizeof(AudioStreamBasicDescription)) return kAudioHardwareBadPropertySizeError;
        *((AudioStreamBasicDescription*)outData) = AudioRouterStreamFormat();
        *outDataSize = sizeof(AudioStreamBasicDescription);
        return kAudioHardwareNoError;
    case kAudioStreamPropertyAvailableVirtualFormats:
    case kAudioStreamPropertyAvailablePhysicalFormats:
        if (inDataSize < sizeof(AudioStreamRangedDescription)) return kAudioHardwareBadPropertySizeError;
        *((AudioStreamRangedDescription*)outData) = AudioRouterRangedFormat();
        *outDataSize = sizeof(AudioStreamRangedDescription);
        return kAudioHardwareNoError;
    default:
        return kAudioHardwareUnknownPropertyError;
    }
}

static OSStatus AudioRouterSetPropertyData(
    AudioServerPlugInDriverRef inDriver,
    AudioObjectID inObjectID,
    pid_t inClientProcessID,
    const AudioObjectPropertyAddress* inAddress,
    UInt32 inQualifierDataSize,
    const void* inQualifierData,
    UInt32 inDataSize,
    const void* inData
) {
    if (inObjectID == kAudioRouterDeviceObjectID && inAddress != NULL && inAddress->mSelector == kAudioDevicePropertyBufferFrameSize) {
        return kAudioHardwareNoError;
    }
    return kAudioHardwareUnsupportedOperationError;
}

static OSStatus AudioRouterStartIO(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID) {
    if (inDeviceObjectID != kAudioRouterDeviceObjectID) return kAudioHardwareBadDeviceError;
    AudioRouterMapSharedInput();
    if (gRunningClientCount == 0) {
        gStartHostTime = mach_absolute_time();
        gTimeStampSeed += 1;
        if (gSharedInput != NULL) {
            gSharedInputReadFrame = gSharedInput->writeFrame;
        }
    }
    gRunningClientCount += 1;
    return kAudioHardwareNoError;
}

static OSStatus AudioRouterStopIO(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID) {
    if (inDeviceObjectID != kAudioRouterDeviceObjectID) return kAudioHardwareBadDeviceError;
    if (gRunningClientCount > 0) {
        gRunningClientCount -= 1;
    }
    return kAudioHardwareNoError;
}

static OSStatus AudioRouterGetZeroTimeStamp(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, Float64* outSampleTime, UInt64* outHostTime, UInt64* outSeed) {
    if (inDeviceObjectID != kAudioRouterDeviceObjectID) return kAudioHardwareBadDeviceError;
    UInt64 now = mach_absolute_time();
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    UInt64 elapsedTicks = now - gStartHostTime;
    Float64 elapsedNanos = ((Float64)elapsedTicks * (Float64)timebase.numer) / (Float64)timebase.denom;
    if (outSampleTime != NULL) *outSampleTime = (elapsedNanos / 1000000000.0) * kAudioRouterSampleRate;
    if (outHostTime != NULL) *outHostTime = now;
    if (outSeed != NULL) *outSeed = gTimeStampSeed;
    return kAudioHardwareNoError;
}

static OSStatus AudioRouterWillDoIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, UInt32 inOperationID, Boolean* outWillDo, Boolean* outWillDoInPlace) {
    if (outWillDo == NULL || outWillDoInPlace == NULL) return kAudioHardwareIllegalOperationError;
    if (inDeviceObjectID != kAudioRouterDeviceObjectID) return kAudioHardwareBadDeviceError;
    *outWillDo = (inOperationID == kAudioServerPlugInIOOperationReadInput);
    *outWillDoInPlace = true;
    return kAudioHardwareNoError;
}

static OSStatus AudioRouterBeginIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, UInt32 inOperationID, UInt32 inIOBufferFrameSize, const AudioServerPlugInIOCycleInfo* inIOCycleInfo) {
    return inDeviceObjectID == kAudioRouterDeviceObjectID ? kAudioHardwareNoError : kAudioHardwareBadDeviceError;
}

static OSStatus AudioRouterDoIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, AudioObjectID inStreamObjectID, UInt32 inClientID, UInt32 inOperationID, UInt32 inIOBufferFrameSize, const AudioServerPlugInIOCycleInfo* inIOCycleInfo, void* ioMainBuffer, void* ioSecondaryBuffer) {
    if (inDeviceObjectID != kAudioRouterDeviceObjectID) return kAudioHardwareBadDeviceError;
    if (inStreamObjectID != kAudioRouterInputStreamObjectID) return kAudioHardwareBadStreamError;
    if (inOperationID != kAudioServerPlugInIOOperationReadInput) return kAudioHardwareNoError;
    UInt32 byteCount = inIOBufferFrameSize * kAudioRouterChannelCount * kAudioRouterBytesPerSample;
    if (ioMainBuffer != NULL) {
        memset(ioMainBuffer, 0, byteCount);
    }
    if (ioSecondaryBuffer != NULL) {
        memset(ioSecondaryBuffer, 0, byteCount);
    }
    if (gSharedInput == NULL || gSharedInputSamples == NULL || ioMainBuffer == NULL) {
        return kAudioHardwareNoError;
    }

    uint64_t writeFrame = gSharedInput->writeFrame;
    uint64_t capacity = gSharedInput->frameCapacity;
    if (capacity == 0 || capacity > AUDIO_ROUTER_SHM_FRAME_CAPACITY || writeFrame <= gSharedInputReadFrame) {
        return kAudioHardwareNoError;
    }

    if (writeFrame - gSharedInputReadFrame > capacity) {
        gSharedInputReadFrame = writeFrame - capacity;
    }
    if (writeFrame - gSharedInputReadFrame < inIOBufferFrameSize) {
        gSharedInputReadFrame = writeFrame > inIOBufferFrameSize ? writeFrame - inIOBufferFrameSize : 0;
    }

    Float32* destination = (Float32*)ioMainBuffer;
    for (UInt32 frame = 0; frame < inIOBufferFrameSize; frame += 1) {
        if (gSharedInputReadFrame >= writeFrame) {
            break;
        }
        uint64_t sourceFrame = gSharedInputReadFrame % capacity;
        size_t sourceIndex = (size_t)sourceFrame * kAudioRouterChannelCount;
        size_t destinationIndex = (size_t)frame * kAudioRouterChannelCount;
        destination[destinationIndex] = gSharedInputSamples[sourceIndex];
        destination[destinationIndex + 1] = gSharedInputSamples[sourceIndex + 1];
        gSharedInputReadFrame += 1;
    }
    return kAudioHardwareNoError;
}

static OSStatus AudioRouterEndIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, UInt32 inOperationID, UInt32 inIOBufferFrameSize, const AudioServerPlugInIOCycleInfo* inIOCycleInfo) {
    return inDeviceObjectID == kAudioRouterDeviceObjectID ? kAudioHardwareNoError : kAudioHardwareBadDeviceError;
}
