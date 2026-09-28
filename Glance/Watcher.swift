import Foundation

struct Watcher: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var backendURL: String
    var token: String
    var mode: Mode
    var pollIntervalMinutes: Int
    var registrationStatus: RegistrationStatus

    init(
        id: UUID = UUID(),
        name: String = "",
        backendURL: String = "",
        token: String = "",
        mode: Mode = .push,
        pollIntervalMinutes: Int = 15,
        registrationStatus: RegistrationStatus = .unregistered
    ) {
        self.id = id
        self.name = name
        self.backendURL = backendURL
        self.token = token
        self.mode = mode
        self.pollIntervalMinutes = pollIntervalMinutes
        self.registrationStatus = registrationStatus
    }

    enum Mode: String, Codable, CaseIterable {
        case push
        case poll

        var label: String { rawValue.capitalized }
        var systemImage: String {
            switch self {
            case .push: return "antenna.radiowaves.left.and.right"
            case .poll: return "arrow.clockwise"
            }
        }
    }

    enum RegistrationStatus: String, Codable {
        case unregistered
        case registered
        case failed
    }

    var trimmedURL: String {
        let cleaned = backendURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        // A bare host (no scheme) is ambiguous and, without a scheme, unusable by
        // URLSession. Default to HTTPS — an explicit http:// is left untouched so a
        // user can still target a plaintext service on a trusted local network.
        guard !cleaned.isEmpty else { return cleaned }
        let lower = cleaned.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return cleaned
        }
        return "https://\(cleaned)"
    }

    /// True when the resolved URL sends unencrypted traffic. Surfaced as a warning.
    var usesPlaintextHTTP: Bool {
        trimmedURL.lowercased().hasPrefix("http://")
    }
}

extension Watcher.RegistrationStatus {
    var label: String {
        switch self {
        case .unregistered: return "Not registered"
        case .registered:   return "Registered"
        case .failed:       return "Failed"
        }
    }
}
