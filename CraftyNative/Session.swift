import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var api: CraftyAPI?
    @Published private(set) var address = ""
    @Published var servers: [JSONValue] = []
    @Published var busy = false
    @Published var error: String?

    init() {
        if let saved = KeychainStore.load() {
            address = saved.0
            api = try? CraftyAPI(address: saved.0, token: saved.1)
        }
    }

    func connect(address: String, token: String) async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            let candidate = try CraftyAPI(address: address, token: token)
            let response = try await candidate.request("GET", "servers")
            let list = response.items.isEmpty ? response["servers"]?.items ?? [] : response.items
            self.api = candidate
            self.address = candidate.baseURL.absoluteString
            self.servers = await enrichedServers(list, api: candidate)
            KeychainStore.save(address: self.address, token: candidate.token)
        } catch { self.error = error.localizedDescription }
    }

    func login(address: String, username: String, password: String, totp: String = "", backupCode: String = "") async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            let token = try await CraftyAPI.login(address: address, username: username, password: password, totp: totp, backupCode: backupCode)
            let candidate = try CraftyAPI(address: address, token: token)
            let response = try await candidate.request("GET", "servers")
            self.servers = await enrichedServers(response.items.isEmpty ? response["servers"]?.items ?? [] : response.items, api: candidate)
            self.api = candidate
            self.address = candidate.baseURL.absoluteString
            KeychainStore.save(address: self.address, token: token)
        } catch { self.error = error.localizedDescription }
    }

    func refresh() async {
        guard let api else { return }
        do {
            let response = try await api.request("GET", "servers")
            servers = await enrichedServers(response.items.isEmpty ? response["servers"]?.items ?? [] : response.items, api: api)
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func disconnect() {
        KeychainStore.clear()
        api = nil
        address = ""
        servers = []
        error = nil
    }

    private func enrichedServers(_ list: [JSONValue], api: CraftyAPI) async -> [JSONValue] {
        await withTaskGroup(of: (Int, JSONValue).self) { group in
            for (index, server) in list.enumerated() {
                group.addTask {
                    guard !server.serverID.isEmpty else { return (index, server) }
                    guard let stats = try? await api.request("GET", "servers/\(server.serverID)/stats"),
                          let running = stats["running"] else { return (index, server) }
                    return (index, server.setting("running", to: .bool(running.boolean)))
                }
            }
            var result = list
            for await (index, value) in group { result[index] = value }
            return result
        }
    }
}

extension JSONValue {
    var serverID: String { self["server_id"]?.text ?? self["id"]?.text ?? "" }
    var serverName: String { self["server_name"]?.text ?? self["name"]?.text ?? "Server" }
    var isRunning: Bool { self["running"]?.boolean ?? self["stats"]?["running"]?.boolean ?? false }
}
