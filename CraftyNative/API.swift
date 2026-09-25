import Foundation
import Security

enum JSONValue: Codable, Equatable, Hashable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null

    init(from decoder: Decoder) throws {
        let box = try decoder.singleValueContainer()
        if box.decodeNil() { self = .null }
        else if let value = try? box.decode(Bool.self) { self = .bool(value) }
        else if let value = try? box.decode(Double.self) { self = .number(value) }
        else if let value = try? box.decode(String.self) { self = .string(value) }
        else if let value = try? box.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try box.decode([JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var box = encoder.singleValueContainer()
        switch self {
        case .object(let v): try box.encode(v)
        case .array(let v): try box.encode(v)
        case .string(let v): try box.encode(v)
        case .number(let v): try box.encode(v)
        case .bool(let v): try box.encode(v)
        case .null: try box.encodeNil()
        }
    }

    subscript(_ key: String) -> JSONValue? {
        guard case .object(let value) = self else { return nil }
        return value[key]
    }

    var items: [JSONValue] {
        if case .array(let value) = self { return value }
        return []
    }

    var text: String {
        switch self {
        case .string(let v): return v
        case .number(let v): return v.rounded() == v ? String(Int(v)) : String(v)
        case .bool(let v): return v ? "Ja" : "Nein"
        case .null: return "–"
        default: return pretty
        }
    }

    var boolean: Bool {
        switch self { case .bool(let v): return v; case .number(let v): return v != 0; default: return false }
    }

    var pretty: String {
        guard let data = try? JSONEncoder().encode(self),
              let object = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
              let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
        else { return "{}" }
        return String(decoding: formatted, as: UTF8.self)
    }

    static func parse(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }
}

enum APIError: LocalizedError {
    case invalidURL, insecureURL, badResponse, server(Int, String), application(String), invalidCredentials

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Bitte eine gültige Serveradresse eingeben."
        case .insecureURL: return "Die Verbindung benötigt HTTPS."
        case .badResponse: return "Crafty hat keine lesbare Antwort gesendet."
        case .server(let code, let message): return "HTTP \(code): \(message)"
        case .application(let message): return message
        case .invalidCredentials: return "Die Anmeldung hat keinen API-Token geliefert."
        }
    }
}

struct CraftyAPI {
    let baseURL: URL
    let token: String

    init(address: String, token: String) throws {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.fragment == nil, url.query == nil else { throw APIError.invalidURL }
        guard url.scheme?.lowercased() == "https" else { throw APIError.insecureURL }
        self.baseURL = url
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func request(_ method: String = "GET", _ route: String, body: JSONValue? = nil) async throws -> JSONValue {
        let data = try await raw(method, route, body: body)
        if data.isEmpty { return .null }
        guard let decoded = try? JSONDecoder().decode(JSONValue.self, from: data) else { throw APIError.badResponse }
        if decoded["status"]?.text.lowercased() == "error" {
            throw APIError.application(decoded["error"]?["message"]?.text ?? decoded["error"]?.text ?? decoded["message"]?.text ?? "Crafty hat die Anfrage abgelehnt.")
        }
        return decoded["data"] ?? decoded
    }

    func raw(_ method: String = "GET", _ route: String, body: JSONValue? = nil) async throws -> Data {
        let rawRoute = route.hasPrefix("/") ? String(route.dropFirst()) : route
        let cleaned = rawRoute.hasPrefix("api/v2/") ? String(rawRoute.dropFirst(7)) : rawRoute
        guard !cleaned.contains("#"), !cleaned.contains("\\"), !cleaned.hasPrefix("//"),
              let relative = URLComponents(string: cleaned), relative.scheme == nil, relative.host == nil else { throw APIError.invalidURL }
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/api/v2/" + cleaned) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method.uppercased()
        request.timeoutInterval = 25
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.badResponse }
        guard (200...299).contains(response.statusCode) else {
            let decoded = try? JSONDecoder().decode(JSONValue.self, from: data)
            let message = decoded?["error"]?["message"]?.text ?? decoded?["message"]?.text ?? String(decoding: data.prefix(250), as: UTF8.self)
            throw APIError.server(response.statusCode, message)
        }
        return data
    }

    static func login(address: String, username: String, password: String) async throws -> String {
        let api = try CraftyAPI(address: address, token: "")
        let result = try await api.request("POST", "auth/login", body: .object(["username": .string(username), "password": .string(password)]))
        guard let token = result["token"]?.text ?? result["access_token"]?.text, !token.isEmpty else { throw APIError.invalidCredentials }
        return token
    }
}

enum KeychainStore {
    private static let service = "com.craftynative.connection"

    static func save(address: String, token: String) {
        let value = try? JSONEncoder().encode(["address": address, "token": token])
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)
        guard let value else { return }
        var item = query
        item[kSecValueData as String] = value
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    static func load() -> (String, String)? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let values = try? JSONDecoder().decode([String: String].self, from: data),
              let address = values["address"], let token = values["token"] else { return nil }
        return (address, token)
    }

    static func clear() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary)
    }
}
