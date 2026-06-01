import Foundation

public struct ProcessAudioMonitorSnapshot {
    public let sources: [AudioSource]
    public let processTapsSupported: Bool
    public let meterMessage: String

    public init(sources: [AudioSource], processTapsSupported: Bool, meterMessage: String) {
        self.sources = sources
        self.processTapsSupported = processTapsSupported
        self.meterMessage = meterMessage
    }
}

public final class ProcessAudioMonitor {
    private let client: CoreAudioClient
    private let runningAppService: RunningAppService
    private let processTapManager: ProcessTapManager

    public convenience init() {
        self.init(
            client: CoreAudioClient(),
            runningAppService: RunningAppService(),
            processTapManager: ProcessTapManager()
        )
    }

    init(
        client: CoreAudioClient,
        runningAppService: RunningAppService,
        processTapManager: ProcessTapManager
    ) {
        self.client = client
        self.runningAppService = runningAppService
        self.processTapManager = processTapManager
    }

    public func listRunningApps() -> [AudioSource] {
        runningAppService.listRunningApps()
    }

    public func identifyLikelyAudioApps() -> [AudioSource] {
        runningAppService.identifyLikelyAudioApps()
    }

    public var meterAvailabilityMessage: String {
        processTapManager.isSupportedOnThisOS
            ? "Live app detection uses CoreAudio process objects. Assign an app to an output to start process-tap routing and real meters."
            : "Process-tap metering requires macOS 14.2 or newer."
    }

    public func snapshot() -> ProcessAudioMonitorSnapshot {
        let coreAudioSources = (try? client.audioSources()) ?? []
        let sources = coreAudioSources.isEmpty ? identifyLikelyAudioApps() : coreAudioSources
        return ProcessAudioMonitorSnapshot(
            sources: withSystemAudioSource(sources),
            processTapsSupported: processTapManager.isSupportedOnThisOS,
            meterMessage: meterAvailabilityMessage
        )
    }

    public func probeFirstAvailableProcessTap(from sources: [AudioSource]) -> ProcessTapProbeResult {
        guard let source = sources.first(where: { $0.audioObjectID != nil }),
              let processObjectID = source.audioObjectID else {
            return ProcessTapProbeResult(
                status: .unavailable("No CoreAudio process object is available to probe."),
                message: "Start audio in an app, refresh, then probe process-tap permission again."
            )
        }
        return processTapManager.probeProcessTap(for: processObjectID)
    }

    public func probeSystemAudioPermission() -> ProcessTapProbeResult {
        processTapManager.probeSystemAudioPermission()
    }

    private func withSystemAudioSource(_ sources: [AudioSource]) -> [AudioSource] {
        guard !sources.contains(where: { $0.id == "system-sounds" }) else {
            return sources
        }
        let systemAudio = AudioSource(
            id: "system-sounds",
            appName: "System Audio",
            bundleIdentifier: "com.apple.systemsounds",
            processID: 0,
            icon: nil,
            isRunning: true,
            isProducingAudio: false
        )
        return [systemAudio] + sources
    }
}
