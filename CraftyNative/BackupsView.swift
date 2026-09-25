import SwiftUI

struct BackupsView: View {
    @EnvironmentObject private var session: SessionStore
    let serverID: String
    @State private var policies: [JSONValue] = []
    @State private var error: String?
    @State private var loading = false
    @State private var selected: JSONValue?

    private var route: String { "servers/\(serverID)/backups" }

    var body: some View {
        List {
            if let error { Section { ErrorNotice(message: error) } }
            if loading { ProgressView().frame(maxWidth: .infinity) }
            Section("Backup-Konfigurationen") {
                if policies.isEmpty && !loading {
                    EmptyState(icon: "externaldrive", title: "Keine Backups", detail: "Erstelle eine Konfiguration oder aktualisiere die Liste.")
                }
                ForEach(Array(policies.enumerated()), id: \.offset) { element in
                    let policy = element.element
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "externaldrive.fill").foregroundStyle(CraftyStyle.green)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(policy["backup_name"]?.text ?? policy["name"]?.text ?? "Backup")
                                    .font(.headline)
                                Text(policy["backup_id"]?.text ?? policy["id"]?.text ?? "")
                                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }
                        HStack {
                            Button("Jetzt sichern") { selected = policy }
                                .buttonStyle(.borderedProminent)
                            Spacer()
                            NavigationLink("Bearbeiten") {
                                JSONEditorView(title: "Backup", route: policyRoute(policy), initial: policy, method: "PATCH")
                            }.font(.subheadline)
                        }
                    }.padding(.vertical, 7)
                }
            }
            Section {
                NavigationLink {
                    JSONEditorView(title: "Backup einrichten", route: route, initial: .object([:]), method: "POST")
                } label: { Label("Konfiguration erstellen", systemImage: "plus.circle.fill") }
                NavigationLink {
                    ResourceView(title: "Alle Backups", route: route, icon: "externaldrive")
                } label: { Label("Alle Daten und Aktionen", systemImage: "list.bullet") }
            }
        }
        .navigationTitle("Backups")
        .task { await load() }
        .refreshable { await load() }
        .confirmationDialog("Backup jetzt starten?", isPresented: Binding(
            get: { selected != nil }, set: { if !$0 { selected = nil } }
        )) {
            Button("Backup starten") {
                if let policy = selected { Task { await run(policy) } }
                selected = nil
            }
        } message: { Text("Crafty erstellt eine Sicherung für diesen Server.") }
    }

    private func policyRoute(_ policy: JSONValue) -> String {
        let id = policy["backup_id"]?.text ?? policy["id"]?.text ?? ""
        return id.isEmpty ? route : route + "/" + id
    }

    private func load() async {
        guard let api = session.api else { return }
        loading = true
        defer { loading = false }
        do {
            let data = try await api.request("GET", route)
            policies = data.items.isEmpty ? data["backups"]?.items ?? data["items"]?.items ?? [] : data.items
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func run(_ policy: JSONValue) async {
        guard let api = session.api else { return }
        let id = policy["backup_id"]?.text ?? policy["id"]?.text ?? ""
        guard !id.isEmpty else { error = "Diese Backup-Konfiguration hat keine Kennung."; return }
        loading = true
        defer { loading = false }
        do {
            _ = try await api.request("POST", "servers/\(serverID)/action/backup_server/\(id)")
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
