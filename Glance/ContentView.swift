import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: WatcherStore
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if store.watchers.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Glance")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                WatcherEditView()
                    .environmentObject(store)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(store.watchers) { watcher in
                NavigationLink {
                    WatcherDetailView(watcherId: watcher.id)
                        .environmentObject(store)
                } label: {
                    WatcherRow(watcher: watcher)
                }
            }
            .onDelete { store.remove(at: $0) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("No watchers")
                .font(.headline)
            Text("Add a backend to start receiving notifications.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add watcher") { showingAdd = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
}

// MARK: - Row

struct WatcherRow: View {
    let watcher: Watcher

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(watcher.name)
                .font(.headline)
            HStack(spacing: 8) {
                Label(watcher.mode.label, systemImage: watcher.mode.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                StatusBadge(status: watcher.registrationStatus)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Status badge

struct StatusBadge: View {
    let status: Watcher.RegistrationStatus

    var body: some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .unregistered: return Color(uiColor: .secondaryLabel)
        case .registered:   return .green
        case .failed:       return .red
        }
    }
}
