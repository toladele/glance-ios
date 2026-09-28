import SwiftUI

struct WatcherDetailView: View {
    @EnvironmentObject private var store: WatcherStore
    let watcherId: UUID

    @State private var isRegistering = false
    @State private var isPolling = false
    @State private var errorMessage: String?
    @State private var lastChecked: String?
    @State private var showingEdit = false
    // @AppStorage re-renders the view automatically when the token arrives from APNs,
    // unlike a plain computed property which SwiftUI only evaluates at initial render.
    @AppStorage("glance.deviceToken") private var storedDeviceToken: String = ""
    @AppStorage("glance.apnsError") private var apnsError: String = ""

    private var watcher: Watcher? {
        store.watchers.first { $0.id == watcherId }
    }

    var body: some View {
        Group {
            if let watcher {
                content(watcher)
            } else {
                Text("Watcher removed.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) {
            if let watcher {
                WatcherEditView(existing: watcher)
                    .environmentObject(store)
            }
        }
    }

    @ViewBuilder
    private func content(_ watcher: Watcher) -> some View {
        List {
            Section("Configuration") {
                LabeledContent("Mode", value: watcher.mode.label)
                LabeledContent("Backend") {
                    Text(watcher.trimmedURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                if watcher.mode == .poll {
                    LabeledContent("Interval", value: "\(watcher.pollIntervalMinutes) min")
                }
            }

            Section("Status") {
                HStack {
                    Text("Registration")
                    Spacer()
                    StatusBadge(status: watcher.registrationStatus)
                }
                if watcher.mode == .push, !storedDeviceToken.isEmpty {
                    Text(storedDeviceToken)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }

            Section {
                if watcher.mode == .push {
                    if storedDeviceToken.isEmpty {
                        Label("Notifications not allowed for Glance", systemImage: "bell.slash")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Open Notification Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        Button("Retry") {
                            Task { await PushManager.shared.requestAuthorization() }
                        }
                        if !apnsError.isEmpty {
                            Text("APNs error: \(apnsError)")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Button {
                            register(watcher)
                        } label: {
                            if isRegistering {
                                Label("Registering…", systemImage: "arrow.triangle.2.circlepath")
                            } else {
                                Label("Register for push", systemImage: "antenna.radiowaves.left.and.right")
                            }
                        }
                        .disabled(isRegistering)
                    }
                } else {
                    Button {
                        checkNow(watcher)
                    } label: {
                        if isPolling {
                            Label("Checking…", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("Check now", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isPolling)

                    if let lastChecked {
                        Text("Last checked \(lastChecked)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(watcher.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
    }

    private func register(_ watcher: Watcher) {
        isRegistering = true
        errorMessage = nil
        Task {
            do {
                try await PushManager.shared.register(watcher: watcher)
                store.setStatus(.registered, for: watcher.id)
            } catch {
                store.setStatus(.failed, for: watcher.id)
                errorMessage = error.localizedDescription
            }
            isRegistering = false
        }
    }

    private func checkNow(_ watcher: Watcher) {
        isPolling = true
        errorMessage = nil
        Task {
            await PollManager.poll(watcher: watcher)
            lastChecked = Date().formatted(date: .omitted, time: .shortened)
            isPolling = false
        }
    }
}
