import Foundation
import UserNotifications
import BackgroundTasks

enum PollManager {
    static let taskIdentifier = "dev.glance.ios.poll"

    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            handle(task: task as! BGAppRefreshTask)
        }
    }

    static func scheduleNext(after interval: TimeInterval = 15 * 60) {
        let req = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        req.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(req)
    }

    static func poll(watcher: Watcher) async {
        guard let url = URL(string: "\(watcher.trimmedURL)/poll") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !watcher.token.isEmpty {
            req.setValue("Bearer \(watcher.token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try? JSONEncoder().encode(PollRequest(name: watcher.name, limit_chars: 180))

        guard
            let (data, response) = try? await URLSession.shared.data(for: req),
            let http = response as? HTTPURLResponse, http.statusCode == 200,
            let result = try? JSONDecoder().decode(PollResponse.self, from: data)
        else { return }

        let content = UNMutableNotificationContent()
        content.title = result.title
        content.body = result.text
        content.sound = .default

        let notification = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(notification)
    }

    // MARK: - Private

    private static func handle(task: BGAppRefreshTask) {
        scheduleNext()

        // Read directly from UserDefaults — WatcherStore is @MainActor and unavailable here.
        let watchers: [Watcher]
        if let data = UserDefaults.standard.data(forKey: "glance.watchers"),
           let decoded = try? JSONDecoder().decode([Watcher].self, from: data) {
            watchers = decoded
        } else {
            watchers = []
        }

        let pollWatchers = watchers.filter { $0.mode == .poll }
        guard !pollWatchers.isEmpty else {
            task.setTaskCompleted(success: true)
            return
        }

        let t = Task {
            for watcher in pollWatchers {
                await poll(watcher: watcher)
            }
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            t.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    // MARK: - Codable helpers

    private struct PollRequest: Encodable {
        let name: String
        let limit_chars: Int
    }

    private struct PollResponse: Decodable {
        let title: String
        let text: String
    }
}
