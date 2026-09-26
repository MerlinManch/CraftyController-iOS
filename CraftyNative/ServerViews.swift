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
    private var cpuValue: String {
        guard let cpu = stats?["cpu"]?.numeric else { return "–" }
        return String(format: "%.1f %%", cpu)
    }
    private var memoryValue: String {
        guard let raw = stats?["mem"]?.text ?? stats?["memory"]?.text else { return "–" }
        let value = Double(raw.prefix { $0.isNumber || $0 == "." || $0 == "," }.replacingOccurrences(of: ",", with: "."))
        guard let value else { return raw }
        let upper = raw.uppercased()
        let gigabytes: Double
        if upper.contains("GIB") || upper.contains("GB") { gigabytes = value }
        else if upper.contains("MIB") { gigabytes = value / 1024 }
        else if upper.contains("MB") { gigabytes = value / 1000 }
        else if upper.contains("KIB") { gigabytes = value / (1024 * 1024) }
        else if upper.contains("KB") { gigabytes = value / 1_000_000 }
        else { gigabytes = value / 1_000_000_000 }
        return String(format: "%.2f GB", gigabytes)
    }

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
                    MetricTile(title: "CPU", value: cpuValue, icon: "cpu")
                    MetricTile(title: "Speicher", value: memoryValue, icon: "memorychip")
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
                        SchedulesView(serverID: id)
                    }
                    Divider().padding(.leading, 54)
                    destination("Webhooks", icon: "bell.badge", detail: "Benachrichtigungen") {
                        ResourceView(title: "Webhooks", route: "servers/\(id)/webhook", icon: "bell.badge")
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
            let result = try await api.request("GET", "servers/\(serverID)/logs?colors=false&raw=false&html=false")
            func logLines(_ value: JSONValue) -> [String] {
                switch value {
                case .array(let entries): return entries.flatMap(logLines)
                case .string(let line): return [line]
                default: return []
                }
            }
            lines = logLines(result["logs"] ?? result).joined(separator: "\n")
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
            _ = try await api.raw("POST", "servers/\(serverID)/stdin", plainText: value)
            command = ""
            await refresh()
        } catch { self.error = error.localizedDescription }
    }
}

struct SchedulesView: View {
    let serverID: String

    var body: some View {
        List {
            Section {
                Label("Crafty stellt über seine API derzeit keine funktionierende Liste der Zeitpläne bereit. Der GET-Aufruf endet im Crafty-Handler mit einem Serverfehler.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Neuen Zeitplan erstellen") {
                NavigationLink {
                    JSONEditorView(title: "Zeitplan erstellen", route: "servers/\(serverID)/tasks",
                                   initial: .object(["name": .string(""), "enabled": .bool(true),
                                                     "action": .string(""), "interval": .number(1),
                                                     "interval_type": .string("hours"),
                                                     "start_time": .string("00:00"), "one_time": .bool(false)]),
                                   method: "POST")
                } label: { Label("Zeitplan konfigurieren", systemImage: "calendar.badge.plus") }
            }
        }
        .navigationTitle("Zeitpläne")
    }
}
