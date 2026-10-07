import Foundation

enum DriveError: Error {
    case notConfigured
    case badResponse
}

/// Client réseau vers le script Google Apps Script — le seul endroit qui parle à Drive.
/// Toutes les fonctions sont "best effort" côté appelant : en cas d'erreur (hors ligne,
/// script non joignable…), l'app doit rester utilisable en local (voir `DataStore`).
enum DriveBridge {
    struct PullResult: Decodable {
        var clients: [Client]
        var catalog: CatalogData
        var photoNames: [String]
    }

    private static var baseURL: URL? { DriveConfig.isConfigured ? URL(string: DriveConfig.webAppURL) : nil }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func pull() async throws -> PullResult {
        let data = try await get(action: "pull")
        return try decoder.decode(PullResult.self, from: data)
    }

    @discardableResult
    static func pushClient(_ client: Client) async throws -> Client {
        let data = try await post(action: "pushClient", bodyData: try encoder.encode(client))
        return try decoder.decode(Client.self, from: data)
    }

    static func deleteClient(id: UUID) async throws {
        _ = try await post(action: "deleteClient", bodyData: try JSONSerialization.data(withJSONObject: ["id": id.uuidString]))
    }

    @discardableResult
    static func pushCatalog(_ catalog: CatalogData) async throws -> CatalogData {
        let data = try await post(action: "pushCatalog", bodyData: try encoder.encode(catalog))
        return try decoder.decode(CatalogData.self, from: data)
    }

    static func uploadPhoto(name: String, data: Data) async throws {
        let payload: [String: String] = ["name": name, "dataBase64": data.base64EncodedString()]
        _ = try await post(action: "uploadPhoto", bodyData: try JSONSerialization.data(withJSONObject: payload))
    }

    static func downloadPhoto(name: String) async throws -> Data {
        try await get(action: "downloadPhoto", extra: [URLQueryItem(name: "name", value: name)])
    }

    static func deletePhotos(transactionID: UUID) async throws {
        _ = try await post(action: "deletePhotos", bodyData: try JSONSerialization.data(withJSONObject: ["transactionId": transactionID.uuidString]))
    }

    // MARK: - Bas niveau

    private static func get(action: String, extra: [URLQueryItem] = []) async throws -> Data {
        guard let baseURL else { throw DriveError.notConfigured }
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "action", value: action),
            URLQueryItem(name: "secret", value: DriveConfig.secret)
        ] + extra
        let (data, response) = try await URLSession.shared.data(from: comps.url!)
        try checkResponse(response)
        return data
    }

    private static func post(action: String, bodyData: Data) async throws -> Data {
        guard let baseURL else { throw DriveError.notConfigured }
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "action", value: action),
            URLQueryItem(name: "secret", value: DriveConfig.secret)
        ]
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return data
    }

    private static func checkResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DriveError.badResponse
        }
    }
}
