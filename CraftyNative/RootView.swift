import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            if session.api == nil { ConnectionView() }
            else { MainTabs() }
        }
    }
}

private struct ConnectionView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var address = ""
    @State private var token = ""
    @State private var username = ""
    @State private var password = ""
    @State private var secondFactor = ""
    @State private var useBackupCode = false
    @State private var useToken = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(CraftyStyle.green)
                            .frame(width: 74, height: 74)
                            .background(CraftyStyle.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
                        Text("Deine Server.\nImmer griffbereit.")
                            .font(.largeTitle.bold())
                        Text("Verbinde dich mit deinem Crafty Controller.")
                            .foregroundStyle(.secondary)
                    }
                    Picker("Anmeldung", selection: $useToken) {
                        Text("API-Schlüssel").tag(true)
                        Text("Benutzerkonto").tag(false)
                    }.pickerStyle(.segmented)
                    VStack(spacing: 16) {
                        TextField("https://crafty.example.com:8443", text: $address)
                            .textContentType(.URL).keyboardType(.URL).textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Divider()
                        if useToken {
                            SecureField("API-Schlüssel", text: $token)
                                .textContentType(.password).textInputAutocapitalization(.never)
                        } else {
                            TextField("Benutzername", text: $username).textContentType(.username)
                            Divider()
                            SecureField("Passwort", text: $password).textContentType(.password)
                            Divider()
                            Toggle("Backup-Code verwenden", isOn: $useBackupCode)
                            if useBackupCode {
                                TextField("Backup-Code", text: $secondFactor)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                            } else {
                                TextField("6-stelliger 2FA-Code (falls aktiviert)", text: $secondFactor)
                                    .keyboardType(.numberPad).textContentType(.oneTimeCode)
                            }
                        }
                    }
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    if let error = session.error { ErrorNotice(message: error) }
                    Button {
                        Task {
                            if useToken { await session.connect(address: address, token: token) }
                            else { await session.login(address: address, username: username, password: password,
                                                       totp: useBackupCode ? "" : secondFactor,
                                                       backupCode: useBackupCode ? secondFactor : "") }
                        }
                    } label: {
                        HStack {
                            if session.busy { ProgressView().tint(.white) }
                            Text("Verbinden").fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }.frame(maxWidth: .infinity).padding(16)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(CraftyStyle.green, in: RoundedRectangle(cornerRadius: 14))
                    .disabled(session.busy || address.isEmpty || (useToken ? token.isEmpty : username.isEmpty || password.isEmpty))
                    Text("Die Verbindung muss HTTPS und ein vertrauenswürdiges Zertifikat verwenden.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(CraftyStyle.background)
            .navigationBarHidden(true)
        }
    }
}

private struct MainTabs: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Server", systemImage: "square.stack.3d.up") }
            NavigationStack { AdministrationView() }
                .tabItem { Label("Verwaltung", systemImage: "slider.horizontal.3") }
            NavigationStack { WorkspaceView() }
                .tabItem { Label("API", systemImage: "terminal") }
            NavigationStack { AccountView() }
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var session: SessionStore
    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.title2).foregroundStyle(CraftyStyle.green)
                        .frame(width: 48, height: 48)
                        .background(CraftyStyle.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading) {
                        Text("Crafty Controller").font(.headline)
                        Text(session.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }.padding(.vertical, 6)
            }
            if let error = session.error { Section { ErrorNotice(message: error) } }
            Section("Deine Server · \(session.servers.count)") {
                if session.servers.isEmpty {
                    EmptyState(icon: "server.rack", title: "Keine Server", detail: "Ziehe zum Aktualisieren oder prüfe deine Berechtigungen.")
                }
                ForEach(Array(session.servers.enumerated()), id: \.offset) { element in
                    let server = element.element
                    NavigationLink {
                        ServerDetailView(server: server)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "cube.fill")
                                .font(.title2).foregroundStyle(CraftyStyle.green)
                                .frame(width: 46, height: 46)
                                .background(CraftyStyle.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(server.serverName).font(.headline).lineLimit(1)
                                Text(server["server_type"]?.text ?? server["server_id"]?.text ?? "Minecraft")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if server["running"] != nil || server["stats"]?["running"] != nil {
                                StatusPill(running: server.isRunning)
                            } else {
                                Text("Status unbekannt").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Übersicht")
        .toolbar {
            NavigationLink {
                JSONEditorView(title: "Server erstellen", route: "servers", initial: .object([:]), method: "POST")
            } label: { Image(systemName: "plus") }
            .accessibilityLabel("Server erstellen")
        }
        .refreshable { await session.refresh() }
        .task { await session.refresh() }
    }
}

private struct AdministrationView: View {
    var body: some View {
        List {
            Section("Crafty") {
                NavigationLink { ResourceView(title: "Benutzer", route: "users", icon: "person.2") } label: { Label("Benutzer", systemImage: "person.2") }
                NavigationLink { ResourceView(title: "Rollen", route: "roles", icon: "person.badge.key") } label: { Label("Rollen & Rechte", systemImage: "person.badge.key") }
                NavigationLink { ResourceView(title: "Einstellungen", route: "crafty/config", icon: "gearshape") } label: { Label("Systemeinstellungen", systemImage: "gearshape") }
            }
            Section {
                Text("Die angezeigten Aktionen hängen von deinen Crafty-Berechtigungen ab.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Verwaltung")
    }
}

private struct AccountView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var profile: JSONValue?
    @State private var error: String?
    @State private var confirmLogout = false

    var body: some View {
        List {
            Section("Verbindung") {
                LabeledContent("Adresse", value: session.address)
                if let profile {
                    LabeledContent("Benutzer", value: profile["username"]?.text ?? profile["name"]?.text ?? "–")
                    NavigationLink("Profil bearbeiten") {
                        JSONEditorView(title: "Mein Profil", route: "users/@me", initial: profile, method: "PATCH")
                    }
                }
            }
            if let error { Section { ErrorNotice(message: error) } }
            Section {
                Button("Abmelden", role: .destructive) { confirmLogout = true }
            }
        }
        .navigationTitle("Profil")
        .task {
            guard let api = session.api else { return }
            do { profile = try await api.request("GET", "users/@me") }
            catch { self.error = error.localizedDescription }
        }
        .confirmationDialog("Verbindung entfernen?", isPresented: $confirmLogout) {
            Button("Abmelden", role: .destructive) { session.disconnect() }
        }
    }
}
