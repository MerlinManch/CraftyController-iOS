import SwiftUI

struct ServerDetailView: View {
    @EnvironmentObject private var session: SessionStore
    let server: JSONValue
    @State private var stats: JSONValue?
    @State private var error: String?
    @State private var busy = false
    @State private var pendingAction: String?

    private var id: String { server.serverID }
    private var running: Bool { stats?["running"]?.boolean ?? server.isRunning }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(server.serverName).font(.largeTitle.bold()).lineLimit(2)
                        StatusPill(running: running)
                    }
                    Spacer()
                    Image(systemName: "cube.transparent.fill")
                        .font(.system(size: 44)).foregroundStyle(CraftyStyle.green)
                }.padding(.top, 8)

                if let error { ErrorNotice(message: error) }
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    MetricTile(title: "Spieler", value: stats?["online"]?.text ?? stats?["players"]?.text ?? "–", icon: "person.2.fill")
                    MetricTile(title: "CPU", value: stats?["cpu"]?.text ?? "–", icon: "cpu")
                    MetricTile(title: "Speicher", value: stats?["mem"]?.text ?? stats?["memory"]?.text ?? "–", icon: "memorychip")
                    MetricTile(title: "Version", value: stats?["version"]?.text ?? "–", icon: "shippingbox")
                }
                HStack(spacing: 10) {
                    Button { Task { await action("start_server") } } label: {
                        Label("Starten", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).disabled(busy || running)
                    Button { pendingAction = "restart_server" } label: {
                        Label("Neustart", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered).disabled(busy || !running)
                    Button { pendingAction = "stop_server" } label: {
                        Image(systemName: "stop.fill").frame(width: 30)
                    }.buttonStyle(.bordered).tint(.red).disabled(busy || !running)
                }
                if busy { ProgressView().frame(maxWidth: .infinity) }

                VStack(spacing: 0) {
                    destination("Konsole", icon: "terminal", detail: "Logs und Befehle") { ConsoleView(serverID: id) }
                    Divider().padding(.leading, 54)
                    destination("Dateien", icon: "folder", detail: "Serverdateien verwalten") { FilesView(serverID: id) }
                    Divider().padding(.leading, 54)
                    destination("Backups", icon: "externaldrive", detail: "Sicherungen verwalten") {
                        BackupsView(serverID: id)
                    }
                    Divider().padding(.leading, 54)
                    destination("Zeitpläne", icon: "calendar.badge.clock", detail: "Automatische Aufgaben") {
                        ResourceView(title: "Zeitpläne", route: "servers/\(id)/tasks", icon: "calendar.badge.clock")
                    }
                    Divider().padding(.leading, 54)
                    destination("Webhooks", icon: "bell.badge", detail: "Benachrichtigungen") {
                        ResourceView(title: "Webhooks", route: "servers/\(id)/webhooks", icon: "bell.badge")
                    }
                    Divider().padding(.leading, 54)
                    destination("Servereinstellungen", icon: "gearshape", detail: "Konfiguration und Rechte") {
                        ResourceView(title: "Servereinstellungen", route: "servers/\(id)", icon: "gearshape")
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(16)
        }
        .background(CraftyStyle.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Aktualisieren", systemImage: "arrow.clockwise") { Task { await refresh() } } }
        .task { await refresh() }
        .refreshable { await refresh() }
        .confirmationDialog("Serveraktion ausführen?", isPresented: Binding(
            get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }
        )) {
            if let pendingAction {
                Button(pendingAction == "stop_server" ? "Server stoppen" : "Server neu starten", role: .destructive) {
                    Task { await action(pendingAction) }
                    self.pendingAction = nil
                }
            }
        } message: { Text("Verbundenen Spielern kann die Verbindung verloren gehen.") }
    }

    private func destination<Content: View>(_ title: String, icon: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        NavigationLink(destination: content()) {
            HStack(spacing: 14) {
                Image(systemName: icon).frame(width: 26).foregroundStyle(CraftyStyle.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }.padding(16).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func refresh() async {
        guard let api = session.api, !id.isEmpty else { return }
        do { stats = try await api.request("GET", "servers/\(id)/stats"); error = nil }
        catch { self.error = error.localizedDescription }
    }

    private func action(_ name: String) async {
        guard let api = session.api else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await api.request("POST", "servers/\(id)/action/\(name)")
            try? await Task.sleep(for: .seconds(1))
            await refresh()
            await session.refresh()
        } catch { self.error = error.localizedDescription }
    }
}

struct ConsoleView: View {
    @EnvironmentObject private var session: SessionStore
    let serverID: String
    @State private var lines = ""
    @State private var command = ""
    @State private var error: String?
    @State private var sending = false

    var body: some View {
        VStack(spacing: 0) {
            if let error { ErrorNotice(message: error).padding(12) }
            ScrollViewReader { proxy in
                ScrollView {
                    Text(lines.isEmpty ? "Keine Ausgaben vorhanden." : lines)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(16)
                        .id("bottom")
                }
                .background(Color(red: 0.07, green: 0.10, blue: 0.09))
                .onChange(of: lines) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            }
            HStack(spacing: 12) {
                TextField("Befehl eingeben", text: $command)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.send).onSubmit { Task { await send() } }
                Button { Task { await send() } } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }
                    .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
            }.padding(14).background(.regularMaterial)
        }
        .navigationTitle("Konsole")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Neu laden", systemImage: "arrow.clockwise") { Task { await refresh() } } }
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func refresh() async {
        guard let api = session.api else { return }
        do {
            let result = try await api.request("GET", "servers/\(serverID)/logs")
            if case .array(let items) = result { lines = items.map(\.text).joined(separator: "\n") }
            else { lines = result["logs"]?.items.map(\.text).joined(separator: "\n") ?? result["logs"]?.text ?? result.text }
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func send() async {
        guard let api = session.api else { return }
        let value = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        sending = true
        defer { sending = false }
        do {
            _ = try await api.request("POST", "servers/\(serverID)/action/send_command", body: .object(["command": .string(value)]))
            command = ""
            await refresh()
        } catch { self.error = error.localizedDescription }
    }
}
