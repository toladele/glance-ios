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

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
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

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...204).contains(http.statusCode) else {
            throw PushError.registrationRejected
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
        case registrationRejected

        var errorDescription: String? {
            switch self {
            case .noDeviceToken:
                return "Notifications not yet authorized. Allow notifications first, then try again."
            case .invalidURL:
                return "The backend URL is invalid."
            case .registrationRejected:
                return "The backend rejected the registration. Check the URL and token."
            }
        }
    }
}
