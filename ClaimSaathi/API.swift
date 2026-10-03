import Foundation
import Security

enum TokenStore {
    private static let account = "jwt"
    private static let service = "com.claimsaathi.auth"

    static var token: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true
            ]
            var out: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
                  let data = out as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(query as CFDictionary)
            guard let value = newValue else { return }
            var add = query
            add[kSecValueData as String] = Data(value.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

struct APIErrorBody: Decodable {
    struct Err: Decodable { let code: String; let message: String }
    let error: Err
}

enum APIError: LocalizedError {
    case http(Int, String)
    case unauthorized
    var errorDescription: String? {
        switch self {
        case .http(_, let message): message
        case .unauthorized: "Session expired. Please log in again."
        }
    }
}

@MainActor
final class API {
    static let shared = API()
    let base = URL(string: Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        ?? "https://stamps-logical-modems-dishes.trycloudflare.com/api")!
    var onUnauthorized: () -> Void = {}
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90
        return URLSession(configuration: config)
    }()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func request<T: Decodable>(_ path: String, method: String = "GET", query: [String: String?] = [:], json: Encodable? = nil, body: Data? = nil, contentType: String? = nil) async throws -> T {
        var root = base.absoluteString
        if !root.hasSuffix("/") { root += "/" }
        var components = URLComponents(string: root + path)!
        let items = query.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
        if !items.isEmpty { components.queryItems = items }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        if let token = TokenStore.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let json {
            request.httpBody = try encodeSkippingNulls(json)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let body {
            request.httpBody = body
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 {
            TokenStore.token = nil
            onUnauthorized()
            throw APIError.unauthorized
        }
        guard (200..<300).contains(code) else {
            let message = (try? decoder.decode(APIErrorBody.self, from: data))?.error.message ?? "Request failed (\(code))"
            throw APIError.http(code, message)
        }
        if T.self == EmptyBody.self { return EmptyBody() as! T }
        return try decoder.decode(T.self, from: data)
    }

    func summaryPdfURL(_ claimId: String) -> URL {
        var root = base.absoluteString
        if !root.hasSuffix("/") { root += "/" }
        var components = URLComponents(string: root + "claims/\(claimId)/summary.pdf")!
        components.queryItems = [URLQueryItem(name: "token", value: TokenStore.token)]
        return components.url!
    }

    private func encodeSkippingNulls(_ value: Encodable) throws -> Data {
        let data = try encoder.encode(AnyEncodable(value))
        let object = try JSONSerialization.jsonObject(with: data)
        return try JSONSerialization.data(withJSONObject: stripNulls(object))
    }

    private func stripNulls(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.compactMapValues { item -> Any? in
                if item is NSNull { return nil }
                return stripNulls(item)
            }
        }
        if let array = value as? [Any] { return array.map(stripNulls) }
        return value
    }
}

struct EmptyBody: Codable {}

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

struct Multipart {
    let boundary = "cs-\(UUID().uuidString)"
    private(set) var data = Data()
    var contentType: String { "multipart/form-data; boundary=\(boundary)" }
    mutating func field(_ name: String, _ value: String) {
        data.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
    }
    mutating func file(filename: String, mime: String, bytes: Data) {
        data.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\nContent-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        data.append(bytes)
        data.append("\r\n".data(using: .utf8)!)
    }
    func finalized() -> Data {
        var copy = data
        copy.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return copy
    }
}
