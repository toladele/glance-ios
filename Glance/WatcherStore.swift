import Foundation

private let storageKey = "glance.watchers"

@MainActor
final class WatcherStore: ObservableObject {
    @Published private(set) var watchers: [Watcher] = []

    init() { load() }

    func add(_ watcher: Watcher) {
        watchers.append(watcher)
        persist()
    }

    func update(_ watcher: Watcher) {
        guard let idx = watchers.firstIndex(where: { $0.id == watcher.id }) else { return }
        watchers[idx] = watcher
        persist()
    }

    func remove(at offsets: IndexSet) {
        watchers.remove(atOffsets: offsets)
        persist()
    }

    func setStatus(_ status: Watcher.RegistrationStatus, for id: UUID) {
        guard let idx = watchers.firstIndex(where: { $0.id == id }) else { return }
        watchers[idx].registrationStatus = status
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(watchers) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Watcher].self, from: data)
        else { return }
        watchers = decoded
    }
}
