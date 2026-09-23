import AVFoundation
import UIKit

/// Something worth telling the player about through sound or touch.
///
/// Callers describe what happened, not which sound or haptic to fire, so the
/// two channels can be tuned — or muted — independently of the game logic.
enum FeedbackEvent: CaseIterable, Sendable {
    case pieceSelected
    case move
    case capture
    case check
    case gameEnd
    /// A rejected action, such as a wrong move in puzzle practice.
    case invalidAttempt

    /// Selecting a piece is haptic-only: a sound on every touch is too chatty.
    var recipe: [SoundSynthesis.Partial]? {
        switch self {
        case .pieceSelected: nil
        case .move: GameSoundRecipe.move
        case .capture: GameSoundRecipe.capture
        case .check: GameSoundRecipe.check
        case .gameEnd: GameSoundRecipe.gameEnd
        case .invalidAttempt: GameSoundRecipe.invalidAttempt
        }
    }
}

/// Plays the sound and haptic for a game event, honouring the Settings toggles.
@MainActor
final class FeedbackPlayer {
    static let shared = FeedbackPlayer()

    private let selection = UISelectionFeedbackGenerator()
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private let sounds = GameSoundBoard()

    private init() {}

    /// Renders the sounds and warms the taptic engine, so the first move of a
    /// game is not the one that stutters.
    func prepare() {
        if GamePreference.haptics.value {
            selection.prepare()
            lightImpact.prepare()
        }
        if GamePreference.sounds.value {
            sounds.prepare(FeedbackEvent.allCases)
        }
    }

    func play(_ event: FeedbackEvent) {
        if GamePreference.sounds.value { sounds.play(event) }
        guard GamePreference.haptics.value else { return }
        switch event {
        case .pieceSelected: selection.selectionChanged()
        case .move: lightImpact.impactOccurred()
        case .capture: rigidImpact.impactOccurred(intensity: 1)
        case .check: notification.notificationOccurred(.warning)
        case .gameEnd: notification.notificationOccurred(.success)
        case .invalidAttempt: notification.notificationOccurred(.error)
        }
    }
}

/// Owns the synthesized cues and plays them off the main thread.
///
/// Activating an audio session and building an `AVAudioPlayer` both block until
/// the audio server answers. On the main thread that trips UIKit's hang-risk
/// check and can stall the tap that triggered the sound, so every audio call
/// is confined to this queue — which is also what makes the mutable state here
/// safe without a lock.
private final class GameSoundBoard: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "com.frankzhu.xiangqi-mobile.audio",
        qos: .userInitiated
    )
    /// Queue-confined.
    private var players: [FeedbackEvent: AVAudioPlayer] = [:]
    private var didConfigureSession = false

    func prepare(_ events: [FeedbackEvent]) {
        queue.async { [self] in
            configureSessionIfNeeded()
            for event in events { _ = player(for: event) }
        }
    }

    func play(_ event: FeedbackEvent) {
        guard event.recipe != nil else { return }
        queue.async { [self] in
            configureSessionIfNeeded()
            guard let player = player(for: event) else { return }
            player.currentTime = 0
            player.play()
        }
    }

    private func player(for event: FeedbackEvent) -> AVAudioPlayer? {
        if let existing = players[event] { return existing }
        guard let recipe = event.recipe,
              let player = try? AVAudioPlayer(data: SoundSynthesis.wav(recipe))
        else { return nil }
        player.prepareToPlay()
        players[event] = player
        return player
    }

    /// `.ambient` keeps whatever the player is already listening to running and
    /// lets the ring switch silence the game, which is what a board game should
    /// do.
    private func configureSessionIfNeeded() {
        guard !didConfigureSession else { return }
        didConfigureSession = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
