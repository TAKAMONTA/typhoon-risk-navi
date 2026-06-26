import Foundation

/// 気象庁（JMA）防災情報 JSON から台風データを取得する。
/// targetTc.json でアクティブ台風 ID を取得し、specifications.json で詳細を取得する。
enum JMAFetcher {

    enum FetchError: LocalizedError {
        case invalidResponse
        case http(statusCode: Int)
        case decoding
        case noActiveTyphoons

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "気象庁からの応答が不正です"
            case .http(let code):
                return "気象庁からの取得に失敗しました (\(code))"
            case .decoding:
                return "気象庁データを解釈できませんでした"
            case .noActiveTyphoons:
                return "現在進行中の台風はありません"
            }
        }
    }

    static let targetTcURL = URL(string: "https://www.jma.go.jp/bosai/typhoon/data/targetTc.json")!

    static func specificationsURL(for eventId: String) -> URL {
        URL(string: "https://www.jma.go.jp/bosai/typhoon/data/\(eventId)/specifications.json")!
    }

    /// 現在進行中の台風を返す。0 件の場合は `.noActiveTyphoons` を throw。
    static func fetchActive(
        targetURL: URL = targetTcURL,
        session: URLSession = .shared
    ) async throws -> [Typhoon] {
        let targets = try await fetchActiveTargets(url: targetURL, session: session)
        if targets.isEmpty {
            throw FetchError.noActiveTyphoons
        }

        var typhoons: [Typhoon] = []
        for eventId in targets {
            if let typhoon = try await fetchTyphoon(eventId: eventId, session: session) {
                typhoons.append(typhoon)
            }
        }

        if typhoons.isEmpty {
            throw FetchError.noActiveTyphoons
        }
        return typhoons
    }

    /// targetTc.json からアクティブな eventId 一覧を取得。
    static func fetchActiveTargets(
        url: URL = targetTcURL,
        session: URLSession = .shared
    ) async throws -> [String] {
        let data = try await fetchData(from: url, session: session)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let array = json as? [[String: Any]] else {
            throw FetchError.decoding
        }
        return array.compactMap { $0["tropicalCyclone"] as? String }
    }

    /// 単一 eventId の specifications.json を取得して Typhoon に変換。
    static func fetchTyphoon(
        eventId: String,
        session: URLSession = .shared
    ) async throws -> Typhoon? {
        let url = specificationsURL(for: eventId)
        let data = try await fetchData(from: url, session: session)
        return try JMAParser.parseSpecifications(data, eventId: eventId)
    }

    // MARK: - HTTP

    private static func fetchData(from url: URL, session: URLSession) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 OkinawaTyphoonNavi/0.9",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json, */*;q=0.1", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FetchError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FetchError.http(statusCode: http.statusCode)
        }
        return data
    }
}
