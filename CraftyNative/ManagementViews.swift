import SwiftUI

struct ResourceView: View {
    @EnvironmentObject private var session: SessionStore
    let title: String
    let route: String
    let icon: String
    @State private var customRoute: String
    @State private var result: JSONValue?
    @State private var error: String?
    @State private var loading = false
    @State private var deleteTarget: JSONValue?

    init(title: String, route: String, icon: String) {
        self.title = title
        self.route = route
        self.icon = icon
        _customRoute = State(initialValue: route)
    }

    private var records: [JSONValue] {
        guard let result else { return [] }
        if case .array(let entries) = result { return entries }
        for key in ["items", "servers", "users", "roles", "backups", "tasks", "webhooks", "data"] {
            if let entries = result[key]?.items, !entries.isEmpty { return entries }
        }
        return []
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundStyle(CraftyStyle.green)
                    TextField("API-Pfad", text: $customRoute)
                        .font(.system(.footnote, design: .monospaced))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Neu laden")
                }
            } footer: {
                Text("Pfad relativ zu /api/v2. Je nach Crafty-Version können Routen abweichen.")
            }
            if let error { Section { ErrorNotice(message: error) } }
            if loading { ProgressView().frame(maxWidth: .infinity) }
            if !records.isEmpty {
                Section("Einträge") {
                    ForEach(Array(records.enumerated()), id: \.offset) { element in
                        let item = element.element
                        NavigationLink {
                            JSONEditorView(title: itemTitle(item), route: itemRoute(item), initial: item, method: "PATCH")
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: icon).foregroundStyle(CraftyStyle.green)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(itemTitle(item)).font(.headline).lineLimit(1)
                                    Text(itemID(item)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }.padding(.vertical, 3)
                        }
                        .swipeActions {
                            Button("Löschen", role: .destructive) { deleteTarget = item }
                        }
                    }
                }
            } else if let result {
                Section {
                    NavigationLink {
                        JSONEditorView(title: title, route: customRoute, initial: result, method: "PATCH")
                    } label: { Label("Daten ansehen und bearbeiten", systemImage: "square.and.pencil") }
                }
            } else if !loading && error == nil {
                EmptyState(icon: icon, title: "Keine Einträge", detail: "Zum Aktualisieren nach unten ziehen.")
            }
            Section {
                NavigationLink {
                    JSONEditorView(title: "Neuer Eintrag", route: customRoute, initial: .object([:]), method: "POST")
                } label: { Label("Eintrag erstellen", systemImage: "plus.circle.fill") }
            }
        }
        .navigationTitle(title)
        .task { await load() }
        .refreshable { await load() }
        .confirmationDialog("Eintrag wirklich löschen?", isPresented: Binding(
            get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Endgültig löschen", role: .destructive) {
                if let target = deleteTarget { Task { await delete(target) } }
                deleteTarget = nil
            }
        } message: { Text("Diese Aktion kann nicht rückgängig gemacht werden.") }
    }

    private func itemID(_ item: JSONValue) -> String {
        for key in ["server_id", "backup_id", "schedule_id", "task_id", "webhook_id", "user_id", "role_id", "id", "uuid"] {
            if let value = item[key]?.text, value != "–" { return value }
        }
        return ""
    }

    private func itemTitle(_ item: JSONValue) -> String {
        for key in ["server_name", "username", "name", "backup_name", "schedule_name", "webhook_name", "role_name", "title"] {
            if let value = item[key]?.text, value != "–" { return value }
        }
        return itemID(item).isEmpty ? "Eintrag" : itemID(item)
    }

    private func itemRoute(_ item: JSONValue) -> String {
        let id = itemID(item)
        guard !id.isEmpty else { return customRoute }
        let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return customRoute.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + escaped
    }

    private func load() async {
        guard let api = session.api else { return }
        loading = true
        defer { loading = false }
        do { result = try await api.request("GET", customRoute); error = nil }
        catch { self.error = error.localizedDescription }
    }

    private func delete(_ item: JSONValue) async {
        guard let api = session.api, !itemID(item).isEmpty else { return }
        do { _ = try await api.request("DELETE", itemRoute(item)); await load() }
        catch { self.error = error.localizedDescription }
    }
}

struct JSONEditorView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    let title: String
    let route: String
    let method: String
    @State private var text: String
    @State private var error: String?
    @State private var busy = false
    @State private var confirm = false

    init(title: String, route: String, initial: JSONValue, method: String) {
        self.title = title
        self.route = route
        self.method = method
        _text = State(initialValue: initial.pretty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(method)  /api/v2/\(route)")
                .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                .lineLimit(2).padding(.horizontal, 16)
            if let error { ErrorNotice(message: error).padding(.horizontal, 16) }
            TextEditor(text: $text)
                .font(.system(.subheadline, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
            if busy { ProgressView().frame(maxWidth: .infinity) }
        }
        .padding(.vertical, 16)
        .background(CraftyStyle.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Speichern") { confirm = true }.disabled(busy) }
        .confirmationDialog("Änderungen an Crafty senden?", isPresented: $confirm) {
            Button("\(method)-Anfrage senden") { Task { await save() } }
        } message: { Text("Die Daten werden direkt auf deinem Server geändert.") }
    }

    private func save() async {
        guard let api = session.api else { return }
        busy = true
        defer { busy = false }
        do {
            let body = try JSONValue.parse(text)
            _ = try await api.request(method, route, body: body)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct WorkspaceView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var method = "GET"
    @State private var route = "servers"
    @State private var payloadText = "{}"
    @State private var response = ""
    @State private var error: String?
    @State private var busy = false
    @State private var confirm = false

    var body: some View {
        Form {
            Section("Anfrage") {
                Picker("Methode", selection: $method) {
                    ForEach(["GET", "POST", "PATCH", "PUT", "DELETE"], id: \.self) { Text($0) }
                }.pickerStyle(.segmented)
                TextField("Pfad ab /api/v2/", text: $route)
                    .font(.system(.subheadline, design: .monospaced))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if method != "GET" && method != "DELETE" {
                    Text("JSON-Inhalt").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $payloadText).font(.system(.subheadline, design: .monospaced))
                        .frame(minHeight: 120)
                }
                Button {
                    if method == "GET" { Task { await execute() } }
                    else { confirm = true }
                } label: {
                    HStack { Label("Anfrage senden", systemImage: "paperplane.fill"); Spacer(); if busy { ProgressView() } }
                }.disabled(route.isEmpty || busy)
            }
            if let error { Section { ErrorNotice(message: error) } }
            if !response.isEmpty {
                Section("Antwort") {
                    Text(response).font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Section {
                Text("Erweiterte Funktionen deiner Crafty-Version lassen sich über den API-Pfad aufrufen. Crafty prüft deine Berechtigungen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("API-Werkzeug")
        .confirmationDialog("Anfrage wirklich senden?", isPresented: $confirm) {
            Button("\(method)-Anfrage senden", role: method == "DELETE" ? .destructive : nil) { Task { await execute() } }
        } message: { Text("Schreibende API-Anfragen ändern Daten direkt in Crafty.") }
    }

    private func execute() async {
        guard let api = session.api else { return }
        busy = true
        defer { busy = false }
        do {
            let payload = (method == "GET" || method == "DELETE") ? nil : try JSONValue.parse(payloadText)
            response = try await api.request(method, route, body: payload).pretty
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
