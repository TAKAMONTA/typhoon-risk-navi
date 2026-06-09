import Foundation

/// JTWC (米軍 Joint Typhoon Warning Center) の Western Pacific 警告テキストを取得する。
/// JTWCParser に投げて Typhoon に変換する純粋な fetch + parse の窓口。
///
/// 注意:
///  - JTWC は無料公開だが User-Agent や IP によっては 403 を返すことがある。
///  - 失敗時は呼び出し側がデモデータにフォールバックする想定（ここでは throw する）。
///  - HTTPS なので App Transport Security の例外は不要。
enum JTWCFetcher {

    enum FetchError: LocalizedError {
        case invalidResponse
        case http(statusCode: Int)
        case decoding
        case noActiveTyphoons

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "JTWC からの応答が不正です"
            case .http(let code):
                return "JTWC からの取得に失敗しました (\(code))"
            case .decoding:
                return "JTWC データを解釈できませんでした"
            case .noActiveTyphoons:
                return "現在進行中の台風はありません"
            }
        }
    }

    /// JTWC の Western Pacific 警告ファイル URL
    static let defaultURL = URL(string: "https://www.metoc.navy.mil/jtwc/products/wpacprod.txt")!

    /// 現在進行中の台風を 1 件以上返す。0 件の場合は `.noActiveTyphoons` を throw。
    /// 取得失敗時は `.http` を throw（呼び出し側でデモにフォールバック）。
    static func fetchActive(
        url: URL = defaultURL,
        session: URLSession = .shared
    ) async throws -> [Typhoon] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        // JTWC は素の curl 系 UA で 403 を返すことがあるので、汎用ブラウザ風の UA を送る
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 OkinawaTyphoonNavi/0.9",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/plain, */*;q=0.1", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FetchError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FetchError.http(statusCode: http.statusCode)
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw FetchError.decoding
        }

        let typhoons = JTWCParser.parseWarnings(text)
        if typhoons.isEmpty {
            throw FetchError.noActiveTyphoons
        }
        return typhoons
    }
}
