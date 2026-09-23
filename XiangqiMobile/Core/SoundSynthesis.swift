import Foundation

/// Builds short game sounds as PCM audio, with no bundled assets.
///
/// The app ships no audio files and makes no network requests, and the
/// undocumented `AudioServicesPlaySystemSound` identifiers fail silently when a
/// release of iOS does not carry them. Synthesizing the cues keeps them
/// deterministic, auditable, and testable.
public enum SoundSynthesis {
    public static let sampleRate = 44_100.0

    /// One additive component of a sound.
    public struct Partial: Sendable {
        /// Seconds from the start of the sound.
        public let start: Double
        public let duration: Double
        /// Hertz, or `nil` for a noise burst (the transient of a piece landing).
        public let frequency: Double?
        public let amplitude: Double
        /// Exponential decay rate; larger is more percussive.
        public let decay: Double

        public init(
            start: Double,
            duration: Double,
            frequency: Double?,
            amplitude: Double,
            decay: Double
        ) {
            self.start = start
            self.duration = duration
            self.frequency = frequency
            self.amplitude = amplitude
            self.decay = decay
        }
    }

    /// Renders partials into a 16-bit mono WAV, ready for `AVAudioPlayer`.
    public static func wav(_ partials: [Partial]) -> Data {
        let total = partials.map { $0.start + $0.duration }.max() ?? 0
        let frameCount = max(1, Int((total * sampleRate).rounded(.up)))
        var samples = [Double](repeating: 0, count: frameCount)
        var noise = NoiseGenerator()

        for partial in partials {
            let first = Int(partial.start * sampleRate)
            let length = Int(partial.duration * sampleRate)
            // A one-pole lowpass takes the hiss off the noise burst so it reads
            // as wood rather than static.
            var filtered = 0.0
            for offset in 0..<length {
                let index = first + offset
                guard index >= 0, index < frameCount else { continue }
                let time = Double(offset) / sampleRate
                let envelope = exp(-partial.decay * time)
                let value: Double
                if let frequency = partial.frequency {
                    value = sin(2 * .pi * frequency * time)
                } else {
                    filtered += 0.28 * (noise.next() - filtered)
                    value = filtered
                }
                samples[index] += value * partial.amplitude * envelope
            }
        }

        // A short fade-out prevents a click when the buffer ends mid-cycle.
        let fade = min(frameCount, Int(0.004 * sampleRate))
        for offset in 0..<fade {
            let index = frameCount - fade + offset
            samples[index] *= 1 - Double(offset) / Double(fade)
        }

        return encodeWAV(samples)
    }

    private static func encodeWAV(_ samples: [Double]) -> Data {
        var pcm = Data(capacity: samples.count * 2)
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            let value = Int16(clamped * 32_767)
            pcm.append(UInt8(truncatingIfNeeded: value))
            pcm.append(UInt8(truncatingIfNeeded: value >> 8))
        }

        let rate = UInt32(sampleRate)
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLittleEndian(UInt32(36 + pcm.count))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        data.appendLittleEndian(UInt32(16))       // PCM header size
        data.appendLittleEndian(UInt16(1))        // PCM format
        data.appendLittleEndian(UInt16(1))        // mono
        data.appendLittleEndian(rate)
        data.appendLittleEndian(rate * 2)         // byte rate
        data.appendLittleEndian(UInt16(2))        // block align
        data.appendLittleEndian(UInt16(16))       // bits per sample
        data.append(contentsOf: Array("data".utf8))
        data.appendLittleEndian(UInt32(pcm.count))
        data.append(pcm)
        return data
    }

    /// Deterministic noise, so a given sound renders identically every run.
    private struct NoiseGenerator {
        private var state: UInt64 = 0x9E3779B97F4A7C15

        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(Int32(truncatingIfNeeded: state >> 32)) / Double(Int32.max)
        }
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}

/// The cues the game plays, defined as recipes rather than asset names.
public enum GameSoundRecipe {
    /// A piece meeting the board: a filtered noise transient over a low thump.
    public static let move: [SoundSynthesis.Partial] = [
        .init(start: 0, duration: 0.05, frequency: nil, amplitude: 0.5, decay: 90),
        .init(start: 0, duration: 0.08, frequency: 196, amplitude: 0.35, decay: 55)
    ]

    /// Heavier and lower than a move, with a second thud for the piece removed.
    public static let capture: [SoundSynthesis.Partial] = [
        .init(start: 0, duration: 0.07, frequency: nil, amplitude: 0.7, decay: 70),
        .init(start: 0, duration: 0.12, frequency: 130, amplitude: 0.5, decay: 38),
        .init(start: 0.05, duration: 0.1, frequency: 98, amplitude: 0.32, decay: 42)
    ]

    /// Two rising tones: attention, not alarm.
    public static let check: [SoundSynthesis.Partial] = [
        .init(start: 0, duration: 0.09, frequency: 880, amplitude: 0.34, decay: 26),
        .init(start: 0.09, duration: 0.12, frequency: 1_174, amplitude: 0.34, decay: 22)
    ]

    /// A three-note rise to close the game.
    public static let gameEnd: [SoundSynthesis.Partial] = [
        .init(start: 0, duration: 0.14, frequency: 659, amplitude: 0.3, decay: 16),
        .init(start: 0.12, duration: 0.14, frequency: 880, amplitude: 0.3, decay: 16),
        .init(start: 0.24, duration: 0.26, frequency: 1_319, amplitude: 0.32, decay: 11)
    ]

    /// A low, short buzz for a rejected move.
    public static let invalidAttempt: [SoundSynthesis.Partial] = [
        .init(start: 0, duration: 0.11, frequency: 155, amplitude: 0.42, decay: 20),
        .init(start: 0, duration: 0.11, frequency: 233, amplitude: 0.22, decay: 24)
    ]
}
