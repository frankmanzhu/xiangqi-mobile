import Foundation
import XCTest
@testable import XiangqiCore

final class XiangqiPGNTests: XCTestCase {
    private let standardFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

    func testDecodesCCPDBig5AndNormalizesOpeningMoves() throws {
        let encoded = "W0dhbWUgIkNoaW5lc2UgQ2hlc3MiXQpbRXZlbnQgIqSkrLa576vMrbewqCJdCltSZXN1bHQgIioiXQpbRkVOICJybmJha2FibnIvOS8xYzVjMS9wMXAxcDFwMXAvOS85L1AxUDFQMVAxUC8xQzVDMS85L1JOQkFLQUJOUiB3IC0gLSAwIDEiXQoKMS4grLakR6WtpK0gsKiit7ZporYKKg=="
        let data = try XCTUnwrap(Data(base64Encoded: encoded))

        let decoded = try XiangqiPGNTextDecoder.decode(data)
        XCTAssertEqual(decoded.encoding, .big5)
        XCTAssertTrue(decoded.text.contains("中炮對屏風馬"))

        let game = try XiangqiPGNParser.parse(decoded.text)
        XCTAssertEqual(game.tags["Event"], "中炮對屏風馬")
        XCTAssertEqual(game.sourceMoves, ["炮二平五", "馬８進７"])

        let normalized = try XiangqiPGNNormalizer.normalize(game)
        XCTAssertEqual(normalized.moves.map(\.uci), ["h2e2", "h9g7"])
    }

    func testFallsBackToBig5HKSCSWithoutLossyReplacement() throws {
        // 0x8140 is an HKSCS extension pair and is invalid in strict Big5.
        let decoded = try XiangqiPGNTextDecoder.decode(Data([0x81, 0x40]))
        XCTAssertEqual(decoded.encoding, .big5HKSCS)
        XCTAssertFalse(decoded.text.contains("�"))
    }

    func testParserKeepsCommentsAndIgnoresVariations() throws {
        let text = """
        [Game "Chinese Chess"]
        [Result "1-0"]
        [FEN "\(standardFEN)"]

        1. 炮二平五 {central cannon} (1. 馬二進三 馬８進７) 馬８進７
        2. 馬二進三 ; development
        車９平８ 1-0
        """

        let game = try XiangqiPGNParser.parse(text)
        XCTAssertEqual(game.sourceMoves, ["炮二平五", "馬８進７", "馬二進三", "車９平８"])
        XCTAssertEqual(game.comments, ["central cannon", "development"])
        XCTAssertEqual(game.result, "1-0")

        let normalized = try XiangqiPGNNormalizer.normalize(game)
        XCTAssertEqual(normalized.moves.map(\.uci), ["h2e2", "h9g7", "h0g2", "i9h9"])
    }

    func testChineseNotationSupportsSimplifiedCharactersAndRelativePieces() throws {
        let opening = try ChineseMoveNotationParser.parse("炮二平五", in: .standard)
        XCTAssertEqual(opening.uci, "h2e2")

        let afterRed = try Position.standard.applying(opening)
        let black = try ChineseMoveNotationParser.parse("马８进７", in: afterRed)
        XCTAssertEqual(black.uci, "h9g7")

        let relativePosition = try Position(fen: "4k4/9/9/9/4R4/9/4R4/9/9/4K4 w - - 0 1")
        XCTAssertEqual(try ChineseMoveNotationParser.parse("前車進一", in: relativePosition).uci, "e5e6")
        XCTAssertEqual(try ChineseMoveNotationParser.parse("後車退一", in: relativePosition).uci, "e3e2")
    }

    func testNormalizerReportsPlyAndSourceNotationOnFailure() throws {
        let game = XiangqiPGNGame(
            tags: ["FEN": standardFEN],
            sourceMoves: ["炮二平五", "不是棋步"],
            comments: [],
            result: "*",
            rawMovetext: ""
        )

        XCTAssertThrowsError(try XiangqiPGNNormalizer.normalize(game)) { error in
            guard case .illegalMove(let ply, let notation, _) = error as? XiangqiPGNError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(ply, 2)
            XCTAssertEqual(notation, "不是棋步")
        }
    }

    func testNormalizesPinnedCCPDMiddlegameFixtureFromArbitraryFEN() throws {
        // CCPD commit 368a47a, Dataset/中局/00000001.pgn after lossless Big5 decoding.
        let text = """
        [Game "Chinese Chess"]
        [Event "北方杯 (1)三軍逼宮"]
        [Date "1982"]
        [Red "徐天利"]
        [Black "呂欽"]
        [Result "0-1"]
        [FEN "4kab2/4a4/2R1b1P2/9/p3p4/5p3/P3P1c2/N2Cr4/4A4/3AK4 b - - 0 1"]

        1. 車５平８
        2. 馬九進七 卒６進１
        3. 馬七進六 車８進２
        4. 仕五退四 炮７進３
        5. 帥五進一 車８退１
        6. 帥五進一 車８退３
        7. 車七退四 卒５進１
        8. 炮六退一 卒５進１
        9. 馬六退五 車８平５
        10. 帥五退一 卒６平５
        11. 車七退一 炮７退５
        12. 帥五退一 卒５進１
        13. 仕四進五 炮７平５
        14. 炮六進五 炮５退１
        15. 帥五平四 車５平６
        16. 帥四平五 車６進２

        0-1
        """

        let normalized = try XiangqiPGNNormalizer.normalize(XiangqiPGNParser.parse(text))
        XCTAssertEqual(normalized.moves.count, 31)
        XCTAssertEqual(normalized.moves.first?.uci, "e2h2")
        XCTAssertEqual(normalized.result, "0-1")
        XCTAssertNoThrow(try Position(fen: normalized.startingFEN).replaying(normalized.moves.map(\.uci)))
    }
}
