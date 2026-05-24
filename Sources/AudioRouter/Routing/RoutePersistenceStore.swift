import Foundation

public final class RoutePersistenceStore {
    private let fileURL: URL

    public init(fileURL: URL = try! AppSupport.fileURL(named: "audio-routes.json")) {
        self.fileURL = fileURL
    }

    public func loadRoutes() -> [AudioRoute] {
        guard let data = try? Data(contentsOf: fileURL),
              let routes = try? JSONDecoder().decode([AudioRoute].self, from: data) else {
            return []
        }
        return routes
    }

    public func saveRoutes(_ routes: [AudioRoute]) {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
