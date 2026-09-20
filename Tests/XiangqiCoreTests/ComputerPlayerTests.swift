import XCTest
@testable import XiangqiCore

final class ComputerPlayerTests: XCTestCase {
    func testComputerLevelIsClampedToSupportedRange() {
        XCTAssertEqual(ComputerConfiguration(level: -1, seed: 1).level, 1)
        XCTAssertEqual(ComputerConfiguration(level: 3, seed: 1).level, 3)
        XCTAssertEqual(ComputerConfiguration(level: 99, seed: 1).level, 5)
    }

    func testConfigurationPreservesSeedForRecordedPolicyMetadata() {
        XCTAssertEqual(ComputerConfiguration(level: 2, seed: 12_345).seed, 12_345)
    }
}
