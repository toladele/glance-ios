import SwiftUI

struct WatcherEditView: View {
    @EnvironmentObject private var store: WatcherStore
    @Environment(\.dismiss) private var dismiss

    var existing: Watcher?

    @State private var name: String
    @State private var backendURL: String
    @State private var token: String
    @State private var mode: Watcher.Mode
    @State private var pollIntervalMinutes: Int

    init(existing: Watcher? = nil) {
        self.existing = existing
        _name                = State(initialValue: existing?.name ?? "")
        _backendURL          = State(initialValue: existing?.backendURL ?? "")
        _token               = State(initialValue: existing?.token ?? "")
        _mode                = State(initialValue: existing?.mode ?? .push)
        _pollIntervalMinutes = State(initialValue: existing?.pollIntervalMinutes ?? 15)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !backendURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Watcher") {
                    TextField("Name", text: $name)
                    TextField("Backend URL", text: $backendURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Token (optional)", text: $token)
                }

                Section("Mode") {
                    Picker("Mode", selection: $mode) {
                        ForEach(Watcher.Mode.allCases, id: \.self) { m in
                            Label(m.label, systemImage: m.systemImage).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode == .poll {
                        Stepper(
                            "Interval: \(pollIntervalMinutes) min",
                            value: $pollIntervalMinutes,
                            in: 15...1440,
                            step: 15
                        )
                    }
                }

                if mode == .push {
                    Section {
                        Text("Push mode requires your backend to support APNs delivery via the /register-device endpoint. See the README for the contract.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New watcher" : "Edit watcher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedURL  = backendURL.trimmingCharacters(in: .whitespaces)

        if let existing {
            var updated = existing
            updated.name = trimmedName
            updated.backendURL = trimmedURL
            updated.token = token
            updated.mode = mode
            updated.pollIntervalMinutes = pollIntervalMinutes
            // Reset registration status if the backend URL changed.
            if trimmedURL != existing.trimmedURL {
                updated.registrationStatus = .unregistered
            }
            store.update(updated)
        } else {
            let watcher = Watcher(
                name: trimmedName,
                backendURL: trimmedURL,
                token: token,
                mode: mode,
                pollIntervalMinutes: pollIntervalMinutes
            )
            store.add(watcher)
            if mode == .poll {
                PollManager.scheduleNext(after: TimeInterval(pollIntervalMinutes * 60))
            }
        }
        dismiss()
    }
}
