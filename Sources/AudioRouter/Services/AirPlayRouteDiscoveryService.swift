import Combine
import Foundation

public final class AirPlayRouteDiscoveryService: NSObject, ObservableObject {
    @Published public private(set) var candidates: [AirPlayRouteCandidate] = []

    private let serviceTypes = ["_airplay._tcp.", "_raop._tcp."]
    private var browsers: [NetServiceBrowser] = []
    private var servicesByKey: [String: NetService] = [:]
    private var isRunning = false

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        browsers = serviceTypes.map { serviceType in
            let browser = NetServiceBrowser()
            browser.delegate = self
            browser.includesPeerToPeer = true
            browser.searchForServices(ofType: serviceType, inDomain: "local.")
            return browser
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        browsers.forEach { browser in
            browser.stop()
            browser.delegate = nil
        }
        browsers.removeAll()
        servicesByKey.values.forEach { $0.delegate = nil }
        servicesByKey.removeAll()
        publishCandidates()
    }

    private func serviceKey(_ service: NetService) -> String {
        [service.type, service.domain, service.name].joined(separator: "|")
    }

    private func publishCandidates() {
        let allCandidates = servicesByKey.values.map(candidate(from:))
        var bestByName: [String: AirPlayRouteCandidate] = [:]

        for candidate in allCandidates {
            let key = AirPlayRouteCandidate.normalizedKey(for: candidate.name)
            if let current = bestByName[key] {
                if isPreferred(candidate, over: current) {
                    bestByName[key] = candidate
                }
            } else {
                bestByName[key] = candidate
            }
        }

        let next = bestByName.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        if next != candidates {
            candidates = next
        }
    }

    private func candidate(from service: NetService) -> AirPlayRouteCandidate {
        let name = AirPlayRouteCandidate.displayName(from: service.name)
        return AirPlayRouteCandidate(
            id: AirPlayRouteCandidate.stableID(name: name, serviceType: service.type, domain: service.domain),
            name: name,
            serviceType: service.type,
            domain: service.domain,
            hostName: service.hostName,
            port: service.port > 0 ? service.port : nil
        )
    }

    private func isPreferred(_ candidate: AirPlayRouteCandidate, over current: AirPlayRouteCandidate) -> Bool {
        if candidate.serviceType.localizedCaseInsensitiveContains("_airplay"),
           !current.serviceType.localizedCaseInsensitiveContains("_airplay") {
            return true
        }
        if candidate.hostName != nil, current.hostName == nil {
            return true
        }
        return false
    }
}

extension AirPlayRouteDiscoveryService: NetServiceBrowserDelegate, NetServiceDelegate {
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let key = serviceKey(service)
        servicesByKey[key] = service
        service.delegate = self
        service.resolve(withTimeout: 3)
        if !moreComing {
            publishCandidates()
        }
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        servicesByKey.removeValue(forKey: serviceKey(service))?.delegate = nil
        if !moreComing {
            publishCandidates()
        }
    }

    public func netServiceDidResolveAddress(_ sender: NetService) {
        servicesByKey[serviceKey(sender)] = sender
        publishCandidates()
    }

    public func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        servicesByKey[serviceKey(sender)] = sender
        publishCandidates()
    }

    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        publishCandidates()
    }
}
