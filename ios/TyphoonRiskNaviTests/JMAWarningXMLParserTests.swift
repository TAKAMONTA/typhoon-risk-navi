import XCTest
@testable import TyphoonRiskNavi

/// 防災情報XMLフォールバックのテスト。
/// フィクスチャは 2026-08-02 に実際に配信されていたフィード・VPWW53 電文を縮約したもの。
final class JMAWarningXMLParserTests: XCTestCase {

    // MARK: - フィクスチャ

    /// extra.xml の縮約。471000 は新旧2エントリ（新しい方が選ばれるべき）、
    /// VPWW54 や対象外予報区（130000）のエントリは無視されるべき。
    private let feedFixture = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>高頻度フィード 随時</title>
      <updated>2026-08-02T11:46:07+09:00</updated>
      <link rel="self" href="https://www.data.jma.go.jp/developer/xml/feed/extra.xml"/>
      <entry>
        <title>気象特別警報・警報・注意報</title>
        <id>https://www.data.jma.go.jp/developer/xml/data/20260802015801_0_VPWW53_471000.xml</id>
        <updated>2026-08-02T01:57:59Z</updated>
        <link type="application/xml" href="https://www.data.jma.go.jp/developer/xml/data/20260802015801_0_VPWW53_471000.xml"/>
        <author><name>沖縄気象台</name></author>
      </entry>
      <entry>
        <title>気象警報・注意報（Ｈ２７）</title>
        <id>https://www.data.jma.go.jp/developer/xml/data/20260802015801_0_VPWW54_471000.xml</id>
        <updated>2026-08-02T01:57:59Z</updated>
        <link type="application/xml" href="https://www.data.jma.go.jp/developer/xml/data/20260802015801_0_VPWW54_471000.xml"/>
        <author><name>沖縄気象台</name></author>
      </entry>
      <entry>
        <title>気象特別警報・警報・注意報</title>
        <id>https://www.data.jma.go.jp/developer/xml/data/20260801195831_0_VPWW53_471000.xml</id>
        <updated>2026-08-01T19:58:32Z</updated>
        <link type="application/xml" href="https://www.data.jma.go.jp/developer/xml/data/20260801195831_0_VPWW53_471000.xml"/>
        <author><name>沖縄気象台</name></author>
      </entry>
      <entry>
        <title>気象特別警報・警報・注意報</title>
        <id>https://www.data.jma.go.jp/developer/xml/data/20260802015801_0_VPWW53_472000.xml</id>
        <updated>2026-08-02T01:58:01Z</updated>
        <link type="application/xml" href="https://www.data.jma.go.jp/developer/xml/data/20260802015801_0_VPWW53_472000.xml"/>
        <author><name>南大東島地方気象台</name></author>
      </entry>
      <entry>
        <title>気象特別警報・警報・注意報</title>
        <id>https://www.data.jma.go.jp/developer/xml/data/20260802015801_0_VPWW53_130000.xml</id>
        <updated>2026-08-02T01:58:01Z</updated>
        <link type="application/xml" href="https://www.data.jma.go.jp/developer/xml/data/20260802015801_0_VPWW53_130000.xml"/>
        <author><name>気象庁</name></author>
      </entry>
    </feed>
    """

    /// VPWW53 電文の縮約。Headline にだけ現れる警報名（波浪注意報）は Body 配下ではないので
    /// 発表中一覧に入らないこと、Status「解除」の強風注意報が除外されることを検証できる形。
    private func warningFixture(reportDateTime: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Report xmlns="http://xml.kishou.go.jp/jmaxml1/">
          <Control>
            <Title>気象特別警報・警報・注意報</Title>
            <DateTime>2026-08-02T01:57:01Z</DateTime>
            <Status>通常</Status>
            <EditorialOffice>沖縄気象台</EditorialOffice>
          </Control>
          <Head xmlns="http://xml.kishou.go.jp/jmaxml1/informationBasis1/">
            <Title>気象特別警報・警報・注意報</Title>
            <ReportDateTime>\(reportDateTime)</ReportDateTime>
            <TargetDateTime>\(reportDateTime)</TargetDateTime>
            <Headline>
              <Text>沖縄本島地方では、落雷に注意してください。</Text>
              <Information type="気象警報・注意報（府県予報区等）">
                <Item>
                  <Kind><Name>波浪注意報</Name><Code>16</Code></Kind>
                  <Areas codeType="気象情報／府県予報区・細分区域等">
                    <Area><Name>沖縄本島地方</Name><Code>471000</Code></Area>
                  </Areas>
                </Item>
              </Information>
            </Headline>
          </Head>
          <Body xmlns="http://xml.kishou.go.jp/jmaxml1/body/meteorology1/">
            <Warning type="気象警報・注意報（府県予報区等）">
              <Item>
                <Kind><Name>雷注意報</Name><Status>継続</Status></Kind>
                <Kind><Name>強風注意報</Name><Status>解除</Status></Kind>
                <Area><Name>沖縄本島地方</Name><Code>471000</Code></Area>
              </Item>
            </Warning>
            <Warning type="気象警報・注意報（市町村等をまとめた地域等）">
              <Item>
                <Kind><Name>雷注意報</Name><Status>継続</Status></Kind>
                <Area><Name>本島中南部</Name><Code>471010</Code></Area>
              </Item>
            </Warning>
          </Body>
        </Report>
        """
    }

    // MARK: - parseFeedLinks

    func testParseFeedLinksPicksLatestPerOfficeAndIgnoresOthers() throws {
        let links = JMAWarningXMLParser.parseFeedLinks(Data(feedFixture.utf8))

        // 471000 は新しい方（20260802015801）が選ばれる。VPWW54 は無視。
        XCTAssertEqual(
            links["471000"]?.absoluteString,
            "https://www.data.jma.go.jp/developer/xml/data/20260802015801_0_VPWW53_471000.xml"
        )
        XCTAssertEqual(
            links["472000"]?.absoluteString,
            "https://www.data.jma.go.jp/developer/xml/data/20260802015801_0_VPWW53_472000.xml"
        )
        // 対象4予報区に無い 130000 は含まれない。
        XCTAssertNil(links["130000"])
        XCTAssertEqual(links.count, 2)
    }

    // MARK: - parseWarningXML

    func testParseWarningXMLExtractsHeadlineNamesAndReportTime() throws {
        let xml = warningFixture(reportDateTime: "2026-08-02T10:57:00+09:00")
        let warning = try XCTUnwrap(JMAWarningXMLParser.parseWarningXML(
            Data(xml.utf8), officeCode: "471000", areaName: "沖縄本島地方"
        ))

        XCTAssertEqual(warning.id, "471000")
        XCTAssertEqual(warning.areaName, "沖縄本島地方")
        XCTAssertEqual(warning.headline, "沖縄本島地方では、落雷に注意してください。")
        // 「解除」の強風注意報と、Headline にしか無い波浪注意報は入らない。
        XCTAssertEqual(warning.warningNames, ["雷注意報"])
        XCTAssertEqual(warning.reportDatetime, "2026-08-02T10:57:00+09:00")
        // 既存の日時パース（OfficialWarning.reportDate）と整合していること。
        XCTAssertNotNil(warning.reportDate)
    }

    func testParsedWarningWithRecentReportTimeIsNotStale() throws {
        // 1時間前の発表として生成 → 24時間しきい値の内側なので新鮮扱い。
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let recent = formatter.string(from: Date().addingTimeInterval(-3600))

        let xml = warningFixture(reportDateTime: recent)
        let warning = try XCTUnwrap(JMAWarningXMLParser.parseWarningXML(
            Data(xml.utf8), officeCode: "471000", areaName: "沖縄本島地方"
        ))
        XCTAssertFalse(warning.isStale)
    }

    func testParseWarningXMLReturnsNilWithoutReportDateTime() {
        // ReportDateTime を欠いた壊れた電文は nil（鮮度判定できないデータを流さない）。
        let broken = "<Report><Head><Headline><Text>x</Text></Headline></Head></Report>"
        XCTAssertNil(JMAWarningXMLParser.parseWarningXML(
            Data(broken.utf8), officeCode: "471000", areaName: "沖縄本島地方"
        ))
    }

    // MARK: - choose

    func testChoosePrefersFreshSource() {
        let fresh = makeWarning(minutesAgo: 30)
        let stale = makeWarning(minutesAgo: 60 * 48)

        // JSON が新鮮ならフォールバック不要で JSON。
        XCTAssertEqual(JMAWarningFetcher.choose(json: fresh, xml: stale)?.reportDatetime, fresh.reportDatetime)
        // JSON が古く XML が新鮮なら XML。
        XCTAssertEqual(JMAWarningFetcher.choose(json: stale, xml: fresh)?.reportDatetime, fresh.reportDatetime)
        // 片方しか無ければある方。
        XCTAssertEqual(JMAWarningFetcher.choose(json: nil, xml: fresh)?.reportDatetime, fresh.reportDatetime)
        XCTAssertEqual(JMAWarningFetcher.choose(json: stale, xml: nil)?.reportDatetime, stale.reportDatetime)
        // 両方古ければ JSON（UI の鮮度ガードに委ねる）。
        let stale2 = makeWarning(minutesAgo: 60 * 72)
        XCTAssertEqual(JMAWarningFetcher.choose(json: stale, xml: stale2)?.reportDatetime, stale.reportDatetime)
        XCTAssertNil(JMAWarningFetcher.choose(json: nil, xml: nil))
    }

    private func makeWarning(minutesAgo: Int) -> OfficialWarning {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return OfficialWarning(
            id: "471000",
            areaName: "沖縄本島地方",
            headline: "テスト",
            warningNames: ["雷注意報"],
            reportDatetime: formatter.string(from: Date().addingTimeInterval(-Double(minutesAgo) * 60)),
            detailURL: JMAWarningFetcher.detailPageURL(officeCode: "471000")
        )
    }
}
