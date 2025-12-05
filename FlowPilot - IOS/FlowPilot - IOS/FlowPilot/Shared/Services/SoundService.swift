import Foundation
import AVFoundation

// MARK: - Sound Service
// Handles playing app sounds
class SoundService {
    static let shared = SoundService()

    private var audioPlayer: AVAudioPlayer?

    private init() {
        // Configure audio session for playback
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[SoundService] Failed to configure audio session: \(error)")
        }
        #endif
    }

    // MARK: - Play Completion Sound
    func playCompletionSound() {
        guard let url = Bundle.main.url(forResource: "completion_sound", withExtension: "mp3") else {
            print("[SoundService] Could not find completion_sound.mp3")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 0.5 // Subtle volume
            audioPlayer?.play()
        } catch {
            print("[SoundService] Failed to play completion sound: \(error)")
        }
    }
}
