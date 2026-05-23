import Foundation

public enum RouteResolver {
    public static func updatedRoutes(
        _ routes: [RouteRule],
        devices: [AudioDeviceInfo],
        processes: [AudioProcessInfo],
        applications: [AppSoundSource] = [],
        activeRouteIDs: Set<UUID>
    ) -> [RouteRule] {
        routes.map { route in
            var copy = route
            let matchedProcess = matchingProcess(for: route, in: processes)
            let matchedApplication = matchingApplication(for: route, in: applications)
            let matchedDevice = route.deviceUID.flatMap { uid in
                devices.first { $0.uid == uid && $0.isRoutableOutput }
            }

            if let matchedProcess {
                copy.processObjectID = matchedProcess.processObjectID
                copy.pid = matchedProcess.pid
                copy.bundleID = matchedProcess.bundleID ?? copy.bundleID
                copy.processDisplayName = matchedProcess.displayName
            } else if let matchedApplication {
                copy.processObjectID = matchedApplication.processObjectID
                copy.pid = matchedApplication.pid
                copy.bundleID = matchedApplication.bundleID ?? copy.bundleID
                copy.processDisplayName = matchedApplication.displayName
            }

            if let matchedDevice {
                copy.deviceUID = matchedDevice.uid
                copy.deviceName = matchedDevice.name
            }

            if activeRouteIDs.contains(route.id) {
                copy.status = .running
                copy.lastError = nil
            } else if (matchedProcess == nil && matchedApplication == nil) || matchedDevice == nil {
                copy.status = .unavailable
            } else {
                copy.status = copy.isEnabled ? .ready : .stopped
            }

            return copy
        }
    }

    public static func matchingProcess(for route: RouteRule, in processes: [AudioProcessInfo]) -> AudioProcessInfo? {
        if let processObjectID = route.processObjectID,
           let process = processes.first(where: { $0.processObjectID == processObjectID }) {
            return process
        }

        if let bundleID = route.bundleID,
           let process = processes.first(where: { $0.bundleID == bundleID }) {
            return process
        }

        if let pid = route.pid,
           let process = processes.first(where: { $0.pid == pid }) {
            return process
        }

        return nil
    }

    public static func matchingApplication(for route: RouteRule, in applications: [AppSoundSource]) -> AppSoundSource? {
        if let processObjectID = route.processObjectID,
           let app = applications.first(where: { $0.processObjectID == processObjectID }) {
            return app
        }

        if let bundleID = route.bundleID,
           let app = applications.first(where: { $0.bundleID == bundleID }) {
            return app
        }

        if let pid = route.pid,
           let app = applications.first(where: { $0.pid == pid }) {
            return app
        }

        return applications.first { $0.displayName == route.processDisplayName }
    }
}
