import UIKit
import UserNotifications

final class PushManager {
    static let shared = PushManager()
    private init() {}

    private let tokenKey = "glance.deviceToken"

    var deviceToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    func setToken(_ data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    @MainActor
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        // Already authorized (e.g. enabled in Settings after a prior denial) —
        // requestAuthorization() would return granted=false in this case and skip
        // registration, so we call registerForRemoteNotifications() directly.
        if settings.authorizationStatus == .authorized {
            UIApplication.shared.registerForRemoteNotifications()
            return
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("Push authorization error: \(error)")
        }
    }

    func register(watcher: Watcher) async throws {
        guard let token = deviceToken else { throw PushError.noDeviceToken }

        let urlString = "\(watcher.trimmedURL)/register-device"
        guard let url = URL(string: urlString) else { throw PushError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !watcher.token.isEmpty {
            req.setValue("Bearer \(watcher.token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(RegistrationPayload(
            device_token: token,
            bundle_id: Bundle.main.bundleIdentifier ?? "dev.glance.ios",
            watcher_id: watcher.id.uuidString,
            watcher_name: watcher.name
        ))

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw PushError.registrationRejected(status: -1, body: "No HTTP response")
        }
        guard (200...204).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw PushError.registrationRejected(status: http.statusCode, body: body)
        }
    }

    // MARK: - Types

    private struct RegistrationPayload: Encodable {
        let device_token: String
        let bundle_id: String
        let watcher_id: String
        let watcher_name: String
    }

    enum PushError: LocalizedError {
        case noDeviceToken
        case invalidURL
        case registrationRejected(status: Int, body: String)

        var errorDescription: String? {
            switch self {
            case .noDeviceToken:
                return "Notifications not yet authorized. Allow notifications first, then try again."
            case .invalidURL:
                return "The backend URL is invalid."
            case .registrationRejected(let status, let body):
                let detail = body.isEmpty ? "" : " — \(body)"
                switch status {
                case 401:
                    return "Rejected (401 Unauthorized)\(detail). The token doesn't match the backend."
                case 400:
                    return "Rejected (400 Bad Request)\(detail). The device token or payload is malformed."
                case 404:
                    return "Rejected (404 Not Found)\(detail). Check the backend URL — is the path and port right?"
                default:
                    return "Rejected (HTTP \(status))\(detail). Check the URL and token."
                }
            }
        }
    }
}
