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
    }

    private static var baseURL: URL? { DriveConfig.isConfigured ? URL(string: DriveConfig.webAppURL) : nil }

    /// Le script lit chaque fiche une à une sur Drive : un `pull` peut prendre plus d'une
    /// minute, au-delà du délai par défaut de 60 s d'`URLSession.shared`.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// Le script (`new Date().toISOString()`) écrit les dates avec millisecondes, que
    /// `.iso8601` refuse — on accepte donc les deux formes.
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: string) ?? ISO8601DateFormatter().date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date invalide : \(string)")
        }
        return d
    }()

    /// Google renvoie parfois une page 404 quand le script met trop longtemps à répondre :
    /// on retente une fois avant d'abandonner.
    static func pull() async throws -> PullResult {
        do {
            return try decoder.decode(PullResult.self, from: try await get(action: "pull"))
        } catch {
            return try decoder.decode(PullResult.self, from: try await get(action: "pull"))
        }
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

    /// Le script renvoie la photo en base64 dans du JSON (`dataBase64`), ou un message
    /// d'erreur si elle n'est pas (encore) sur Drive : on ne garde que ce qui est bien un
    /// JPEG.
    static func downloadPhoto(name: String) async throws -> Data {
        let data = try await get(action: "downloadPhoto", extra: [URLQueryItem(name: "name", value: name)])
        let photo = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            .flatMap { $0["dataBase64"] as? String }
            .flatMap { Data(base64Encoded: $0) }
            ?? data
        guard photo.starts(with: [0xFF, 0xD8]) else { throw DriveError.badResponse }
        return photo
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
        let (data, response) = try await session.data(from: comps.url!)
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
        let (data, response) = try await session.data(for: request)
        try checkResponse(response)
        return data
    }

    private static func checkResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DriveError.badResponse
        }
    }
}
