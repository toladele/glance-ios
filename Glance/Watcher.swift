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
        backendURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
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
