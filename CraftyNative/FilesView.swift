import SwiftUI

struct FilesView: View {
    @EnvironmentObject private var session: SessionStore
    let serverID: String
    var path: String = ""
    @State private var entries: [JSONValue] = []
    @State private var error: String?
    @State private var loading = false
    @State private var newFolder = ""
    @State private var showFolder = false
    @State private var deleteEntry: JSONValue?

    private var baseRoute: String { "servers/\(serverID)/files" }

    var body: some View {
        List {
            if !path.isEmpty {
                Section { Text(path).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
            }
            if let error { Section { ErrorNotice(message: error) } }
            if loading { ProgressView().frame(maxWidth: .infinity) }
            Section("Inhalt") {
                if entries.isEmpty && !loading {
                    EmptyState(icon: "folder", title: "Keine Dateien", detail: "Ordner ist leer oder konnte nicht gelesen werden.")
                }
                ForEach(Array(entries.enumerated()), id: \.offset) { element in
                    let entry = element.element
                    let filename = entry["name"]?.text ?? entry["filename"]?.text ?? "Datei"
                    let childPath = path.isEmpty ? filename : path + "/" + filename
                    NavigationLink {
                        if isDirectory(entry) { FilesView(serverID: serverID, path: childPath) }
                        else { FileContentView(serverID: serverID, path: childPath) }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(filename).lineLimit(1)
                                if let size = entry["size"]?.text {
                                    Text("\(size) Bytes").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: isDirectory(entry) ? "folder.fill" : "doc.text")
                                .foregroundStyle(isDirectory(entry) ? CraftyStyle.green : .secondary)
                        }
                    }
                    .swipeActions { Button("Löschen", role: .destructive) { deleteEntry = entry } }
                }
            }
        }
        .navigationTitle(path.isEmpty ? "Dateien" : path.components(separatedBy: "/").last ?? "Dateien")
        .toolbar { Menu {
            Button("Neuer Ordner", systemImage: "folder.badge.plus") { showFolder = true }
            Button("Aktualisieren", systemImage: "arrow.clockwise") { Task { await load() } }
        } label: { Image(systemName: "ellipsis.circle") } }
        .task { await load() }
        .refreshable { await load() }
        .alert("Neuer Ordner", isPresented: $showFolder) {
            TextField("Name", text: $newFolder)
            Button("Erstellen") { Task { await makeFolder() } }
            Button("Abbrechen", role: .cancel) { newFolder = "" }
        }
        .confirmationDialog("Datei oder Ordner löschen?", isPresented: Binding(
            get: { deleteEntry != nil }, set: { if !$0 { deleteEntry = nil } }
        )) {
            Button("Endgültig löschen", role: .destructive) {
                if let entry = deleteEntry { Task { await remove(entry) } }
                deleteEntry = nil
            }
        }
    }

    private func isDirectory(_ entry: JSONValue) -> Bool {
        entry["is_dir"]?.boolean == true || entry["directory"]?.boolean == true ||
        entry["type"]?.text.lowercased() == "directory" || entry["type"]?.text.lowercased() == "dir"
    }

    private func route(for target: String) -> String {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "path", value: target)]
        return baseRoute + (components.percentEncodedQuery.map { "?" + $0 } ?? "")
    }

    private func load() async {
        guard let api = session.api else { return }
        loading = true
        defer { loading = false }
        do {
            let data = try await api.request("GET", route(for: path))
            entries = data.items.isEmpty ? data["files"]?.items ?? data["items"]?.items ?? [] : data.items
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func makeFolder() async {
        guard let api = session.api else { return }
        let name = newFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else {
            error = "Bitte einen gültigen Ordnernamen eingeben."; return
        }
        do {
            _ = try await api.request("POST", baseRoute, body: .object(["path": .string(path), "name": .string(name), "type": .string("directory")]))
            newFolder = ""
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func remove(_ entry: JSONValue) async {
        guard let api = session.api else { return }
        let name = entry["name"]?.text ?? entry["filename"]?.text ?? ""
        guard !name.isEmpty else { return }
        let target = path.isEmpty ? name : path + "/" + name
        do { _ = try await api.request("DELETE", route(for: target)); await load() }
        catch { self.error = error.localizedDescription }
    }
}

private struct FileContentView: View {
    @EnvironmentObject private var session: SessionStore
    let serverID: String
    let path: String
    @State private var content = ""
    @State private var error: String?
    @State private var loading = true
    @State private var saving = false
    @State private var confirmSave = false

    private var route: String {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "path", value: path), URLQueryItem(name: "file", value: "true")]
        return "servers/\(serverID)/files?" + (components.percentEncodedQuery ?? "")
    }

    var body: some View {
        VStack(spacing: 8) {
            if let error { ErrorNotice(message: error).padding(.horizontal) }
            if loading { ProgressView().frame(maxHeight: .infinity) }
            else {
                TextEditor(text: $content)
                    .font(.system(.subheadline, design: .monospaced))
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .padding(8)
            }
        }
        .background(CraftyStyle.background)
        .navigationTitle(path.components(separatedBy: "/").last ?? "Datei")
        .toolbar { Button("Speichern") { confirmSave = true }.disabled(loading || saving) }
        .task { await load() }
        .confirmationDialog("Datei überschreiben?", isPresented: $confirmSave) {
            Button("Speichern") { Task { await save() } }
        }
    }

    private func load() async {
        guard let api = session.api else { return }
        do {
            let data = try await api.raw("GET", route)
            guard data.count <= 2_000_000 else { throw APIError.application("Diese Datei ist für den Texteditor zu groß.") }
            guard let text = String(data: data, encoding: .utf8) else { throw APIError.application("Binärdateien können nicht als Text bearbeitet werden.") }
            if let envelope = try? JSONValue.parse(text), let value = envelope["data"]?["content"] ?? envelope["content"] {
                content = value.text
            } else { content = text }
            error = nil
        } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func save() async {
        guard let api = session.api else { return }
        saving = true
        defer { saving = false }
        do {
            _ = try await api.request("PUT", route, body: .object(["content": .string(content)]))
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
