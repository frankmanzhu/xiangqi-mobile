import XCTest
@testable import XiangqiCore

final class SoundSynthesisTests: XCTestCase {
    private let headerByteCount = 44

    func testRendersAWellFormedWAVHeader() {
        let data = SoundSynthesis.wav(GameSoundRecipe.move)
        XCTAssertGreaterThan(data.count, headerByteCount)
        XCTAssertEqual(Array(data[0..<4]), Array("RIFF".utf8))
        XCTAssertEqual(Array(data[8..<12]), Array("WAVE".utf8))
        XCTAssertEqual(Array(data[36..<40]), Array("data".utf8))

        let declared = data[4..<8].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        XCTAssertEqual(Int(declared), data.count - 8, "RIFF size must cover everything after it")

        let payload = data[40..<44].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        XCTAssertEqual(Int(payload), data.count - headerByteCount)
    }

    func testEveryCueProducesAudibleAudio() {
        let cues: [(String, [SoundSynthesis.Partial])] = [
            ("move", GameSoundRecipe.move),
            ("capture", GameSoundRecipe.capture),
            ("check", GameSoundRecipe.check),
            ("gameEnd", GameSoundRecipe.gameEnd),
            ("invalidAttempt", GameSoundRecipe.invalidAttempt)
        ]
        for (name, recipe) in cues {
            let samples = peakAndLength(of: SoundSynthesis.wav(recipe))
            XCTAssertGreaterThan(samples.peak, 0.05, "\(name) is inaudibly quiet")
            XCTAssertLessThanOrEqual(samples.peak, 1.0, "\(name) clips")
            XCTAssertGreaterThan(samples.seconds, 0.03, "\(name) is too short to hear")
            XCTAssertLessThan(samples.seconds, 1.0, "\(name) outlasts the action")
        }
    }

    func testRenderingIsDeterministic() {
        XCTAssertEqual(
            SoundSynthesis.wav(GameSoundRecipe.capture),
            SoundSynthesis.wav(GameSoundRecipe.capture),
            "noise must be seeded so a cue sounds the same every launch"
        )
    }

    func testCaptureIsWeightierThanAPlainMove() {
        let move = peakAndLength(of: SoundSynthesis.wav(GameSoundRecipe.move))
        let capture = peakAndLength(of: SoundSynthesis.wav(GameSoundRecipe.capture))
        XCTAssertGreaterThan(capture.peak, move.peak)
        XCTAssertGreaterThan(capture.seconds, move.seconds)
    }

    private func peakAndLength(of wav: Data) -> (peak: Double, seconds: Double) {
        let pcm = wav[headerByteCount...]
        var peak = 0.0
        for index in stride(from: pcm.startIndex, to: pcm.endIndex - 1, by: 2) {
            let raw = UInt16(pcm[index]) | (UInt16(pcm[index + 1]) << 8)
            let value = Double(Int16(bitPattern: raw)) / 32_767
            peak = max(peak, abs(value))
        }
        return (peak, Double(pcm.count / 2) / SoundSynthesis.sampleRate)
    }
}
