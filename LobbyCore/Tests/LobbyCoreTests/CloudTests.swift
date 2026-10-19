import XCTest
@testable import LobbyCore

final class CloudTests: XCTestCase {
    func testDecodesDatesWithAndWithoutFractions() throws {
        let json = """
        {"season":2026,"weekends":[{"id":"2026-18","season":2026,"round":18,"name":"United States Grand Prix","shortName":"US Grand Prix","locality":"Austin","sessions":[{"kind":"practice1","start":"2026-10-23T17:30:00.000Z"},{"kind":"qualifying","start":"2026-10-24T21:00:00Z"},{"kind":"race","start":"2026-10-25T20:00:00.000Z"},{"kind":"somethingNew","start":"2026-10-25T20:00:00.000Z"}]}]}
        """
        let doc = try Cloud.decode(Cloud.F1CalendarDoc.self, from: Data(json.utf8))
        let calendar = doc.calendar()
        let austin = try XCTUnwrap(calendar.weekends.first)
        XCTAssertEqual(austin.sessions.map(\.kind), [.practice1, .qualifying, .race], "unknown kinds are dropped")
        XCTAssertEqual(clock.dayAndTime(austin.race!.start), "Mon 6:30am")
        XCTAssertEqual(austin.race?.alarm, austin.race!.start.addingTimeInterval(-900))
        XCTAssertEqual(austin.qualifying?.alarm, austin.qualifying?.start)
        XCTAssertEqual(calendar.phase(at: adelaide(2026, 10, 20)), .raceWeek)
    }

    func testDecodesStandingsLatestAndNews() throws {
        let standings = try Cloud.decode(Cloud.F1StandingsDoc.self, from: Data("""
        {"round":17,"drivers":[{"position":6,"driver":"Norris","teamID":"mclaren","points":201},{"position":7,"driver":"Piastri","teamID":"mclaren","points":138.5}],"updatedAt":"x"}
        """.utf8))
        XCTAssertEqual(standings.standings().map(\.points), [201, 138.5])

        let latest = try Cloud.decode(Cloud.F1LatestDoc.self, from: Data("""
        {"race":{"weekendID":"2026-17","raceName":"Singapore Grand Prix","topThree":["Antonelli","Russell","Norris"]},"qualifying":null}
        """.utf8))
        XCTAssertEqual(latest.race?.topThree.count, 3)
        XCTAssertNil(latest.qualifying)

        let news = try Cloud.decode(Cloud.NewsDoc.self, from: Data("""
        {"items":[{"id":"abc","source":"RaceFans","title":"Norris wins","url":null,"published":"2026-10-19T03:00:00.000Z","mayContainResult":true,"tags":["mclaren"]}],"failedFeeds":[]}
        """.utf8)).news()
        XCTAssertEqual(news.first?.tags, ["mclaren"])
        XCTAssertNil(news.first?.url)
        XCTAssertTrue(news.first!.mayContainResult)
    }

    private func afl(phase: String, live: String = "[]", upcoming: String = "[]", recent: String = "[]") throws -> Cloud.AFLDoc {
        try Cloud.decode(Cloud.AFLDoc.self, from: Data("""
        {"year":2026,"phase":"\(phase)","ladder":[{"rank":15,"teamID":13,"name":"Port Adelaide","played":23,"wins":8,"losses":15,"draws":0,"points":32,"percentage":88.4},{"rank":1,"teamID":7,"name":"Geelong","played":23,"wins":18,"losses":5,"draws":0,"points":72,"percentage":140.1}],
         "live":\(live),"upcoming":\(upcoming),"recent":\(recent),"models":[{"source":"Drop Kick Data","correct":163,"tipped":218},{"source":"Squiggle","correct":160,"tipped":218}]}
        """.utf8))
    }

    private let portVCrows = """
    {"id":1,"round":5,"roundName":"Round 5","homeID":13,"awayID":1,"home":"Port Adelaide","away":"Adelaide","start":"2026-10-24T09:10:00.000Z","venue":"Adelaide Oval","homeScore":67,"awayScore":54,"complete":60,"status":"Q3 14:20"}
    """

    func testOffSeasonStatus() throws {
        let doc = try afl(phase: "offSeason")
        let status = doc.status(for: .portAdelaide, now: handoverMorning, clock: clock)
        XCTAssertEqual(status.phaseLabel, "off-season")
        XCTAssertEqual(status.heroTitle, "Fixture coming")
        XCTAssertEqual(status.clubRows.first?.value, "15th · 8-15")
        XCTAssertEqual(status.tipping.bestModel, "163/218")
        XCTAssertEqual(status.tipping.yourRank, "[n] of 3")
        XCTAssertEqual(status.tipping.note, "Opens with Round 1, 2027")
    }

    func testOffSeasonWithNextSeasonOpener() throws {
        let doc = try afl(phase: "offSeason", upcoming: "[\(portVCrows.replacingOccurrences(of: "\"start\":\"2026-10-24T09:10:00.000Z\"", with: "\"start\":\"2027-03-12T09:10:00.000Z\"").replacingOccurrences(of: "\"complete\":60", with: "\"complete\":0"))]")
        let status = doc.status(for: .portAdelaide, now: handoverMorning, clock: clock)
        XCTAssertEqual(status.heroKicker, "Next season")
        XCTAssertEqual(status.heroTitle, "Round 1 in 144 days")
        XCTAssertEqual(status.clubRows.last?.value, "Fri 12 Mar")
    }

    func testLiveGame() throws {
        let doc = try afl(phase: "season", live: "[\(portVCrows)]")
        let status = doc.status(for: .portAdelaide, now: handoverMorning, clock: clock)
        XCTAssertEqual(status.phaseLabel, "live")
        XCTAssertEqual(status.heroTitle, "Port Adelaide 67  Adelaide 54")
        XCTAssertEqual(status.heroKicker, "Round 5 · Q3 14:20 · Adelaide Oval")
        XCTAssertEqual(status.clubRows.last?.value, "Bye")
    }

    func testNextGameAndLastResult() throws {
        let lastWeek = portVCrows
            .replacingOccurrences(of: "\"start\":\"2026-10-24T09:10:00.000Z\"", with: "\"start\":\"2026-10-17T09:10:00.000Z\"")
            .replacingOccurrences(of: "\"complete\":60", with: "\"complete\":100")
            .replacingOccurrences(of: "\"homeScore\":67,\"awayScore\":54", with: "\"homeScore\":60,\"awayScore\":72")
        let next = portVCrows
            .replacingOccurrences(of: "\"complete\":60", with: "\"complete\":0")
            .replacingOccurrences(of: "\"homeID\":13,\"awayID\":1,\"home\":\"Port Adelaide\",\"away\":\"Adelaide\"", with: "\"homeID\":7,\"awayID\":13,\"home\":\"Geelong\",\"away\":\"Port Adelaide\"")
        let doc = try afl(phase: "season", upcoming: "[\(next)]", recent: "[\(lastWeek)]")
        let status = doc.status(for: .portAdelaide, now: handoverMorning, clock: clock)
        XCTAssertEqual(status.heroTitle, "v Geelong in 5d 9h")
        XCTAssertEqual(status.heroSub, "Sat 7:40pm Adelaide")
        XCTAssertEqual(status.clubRows.last?.value, "Lost to Adelaide by 12")
        XCTAssertEqual(status.tipping.note, "Tipping arrives with the phone build")
    }

    func testOrdinals() {
        XCTAssertEqual([1, 2, 3, 4, 11, 12, 13, 21, 22, 101, 111].map(Cloud.ordinal), ["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd", "101st", "111th"])
    }
}
