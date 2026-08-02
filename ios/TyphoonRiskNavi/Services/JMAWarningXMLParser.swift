import Foundation

/// 気象庁 防災情報XML（Atom フィードと VPWW53 電文）を既存の OfficialWarning へ変換する純関数群。
///
/// bosai JSON 系統（warning/{officeCode}.json）が 2026-05-28 から全国的に更新停止する一方、
/// 防災情報XMLフィードは配信が続いていることを実測確認したため、JSON が古いときの
/// フォールバック経路として導入した。JSON 系統が復旧すればそちらが再び優先される。
///
/// ネットワーク I/O を持たないので、実データから作ったフィクスチャで直接テストできる。
enum JMAWarningXMLParser {

    /// 電文種別。VPWW53（気象特別警報・警報・注意報）は特別警報を含む新形式で、
    /// 同時配信されている VPWW54（H27形式）より情報が広いのでこちらを使う。
    static let telegramType = "VPWW53"

    // MARK: - Atom フィード

    /// フィード(extra.xml)から、予報区コード → 最新の VPWW53 電文 URL を取り出す。
    /// リンク URL が `{timestamp}_0_VPWW53_{officeCode}.xml` 形式なので、
    /// エントリ本文を取得しなくても電文種別と予報区を判定できる。
    static func parseFeedLinks(
        _ data: Data,
        officeCodes: [String] = JMAWarningFetcher.okinawaOffices.map(\.code)
    ) -> [String: URL] {
        let delegate = FeedDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()

        // 同じ予報区のエントリが複数あるときは updated が最新のものを選ぶ。
        // Atom の updated は ISO8601(UTC) 固定書式なので文字列比較で新旧が決まる。
        var best: [String: (updated: String, url: URL)] = [:]
        for entry in delegate.entries {
            guard let href = entry.href, let url = URL(string: href) else { continue }
            guard let office = officeCodes.first(where: {
                href.hasSuffix("_\(telegramType)_\($0).xml")
            }) else { continue }
            if let current = best[office], current.updated >= entry.updated { continue }
            best[office] = (entry.updated, url)
        }
        return best.mapValues(\.url)
    }

    // MARK: - VPWW53 電文

    /// VPWW53 電文から OfficialWarning を組み立てる。必須要素が欠けていれば nil。
    static func parseWarningXML(
        _ data: Data,
        officeCode: String,
        areaName: String
    ) -> OfficialWarning? {
        let delegate = WarningDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()

        // ReportDateTime が取れないものは電文として壊れているとみなす
        // （鮮度判定ができないデータを「現在の警報」として流さない）。
        guard let reportDatetime = delegate.reportDateTime else { return nil }

        let names = delegate.activeWarningNames.sorted()
        let headline = delegate.headlineText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 見出しの整形規則は JSON パーサ（JMAWarningFetcher.parseWarning）と揃える。
        let cleanedHeadline: String
        if names.isEmpty, headline.contains("解除") {
            cleanedHeadline = "現在、発表中の警報・注意報はありません"
        } else if headline.isEmpty {
            cleanedHeadline = names.isEmpty
                ? "現在、発表中の警報・注意報はありません"
                : names.joined(separator: "・")
        } else {
            cleanedHeadline = headline
        }

        return OfficialWarning(
            id: officeCode,
            areaName: areaName,
            headline: cleanedHeadline,
            warningNames: names,
            reportDatetime: reportDatetime,
            detailURL: JMAWarningFetcher.detailPageURL(officeCode: officeCode)
        )
    }

    // MARK: - XMLParser delegates

    /// Atom フィードの entry から updated と link href だけを拾う。
    private final class FeedDelegate: NSObject, XMLParserDelegate {
        struct Entry {
            var updated: String = ""
            var href: String?
        }

        var entries: [Entry] = []
        private var current: Entry?
        private var textBuffer = ""

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            switch elementName {
            case "entry":
                current = Entry()
            case "link":
                // フィード自身の link と区別するため、entry の中にいるときだけ拾う。
                if current != nil, current?.href == nil {
                    current?.href = attributeDict["href"]
                }
            case "updated":
                textBuffer = ""
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            textBuffer += string
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            switch elementName {
            case "updated":
                if current != nil {
                    current?.updated = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case "entry":
                if let entry = current { entries.append(entry) }
                current = nil
            default:
                break
            }
        }
    }

    /// VPWW53 電文から ReportDateTime・Headline/Text・発表中の警報名を拾う。
    private final class WarningDelegate: NSObject, XMLParserDelegate {
        var reportDateTime: String?
        var headlineText = ""
        var activeWarningNames = Set<String>()

        /// 現在の要素パス。Headline の下にも Kind/Name が現れるため、
        /// 警報名は Body 配下の Kind に限定して拾う（Headline 側は Status を持たず誤検出しやすい）。
        private var path: [String] = []
        private var textBuffer = ""
        private var kindName: String?
        private var kindStatus: String?

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            path.append(elementName)
            textBuffer = ""
            if elementName == "Kind", path.contains("Body") {
                kindName = nil
                kindStatus = nil
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            textBuffer += string
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            switch elementName {
            case "ReportDateTime":
                if reportDateTime == nil, !text.isEmpty {
                    reportDateTime = text
                }
            case "Text":
                // 最初の Headline/Text だけを見出しとして採用する。
                if headlineText.isEmpty, path.contains("Headline"), !text.isEmpty {
                    headlineText = text
                }
            case "Name":
                if path.contains("Body"), path.dropLast().last == "Kind" {
                    kindName = text
                }
            case "Status":
                if path.contains("Body"), path.dropLast().last == "Kind" {
                    kindStatus = text
                }
            case "Kind":
                // 「解除」は発表中ではないので数えない。名前が空の Kind も無視する。
                if path.contains("Body"), let name = kindName, !name.isEmpty,
                   kindStatus != "解除" {
                    activeWarningNames.insert(name)
                }
                kindName = nil
                kindStatus = nil
            default:
                break
            }
            path.removeLast()
        }
    }
}
