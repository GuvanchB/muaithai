import SwiftUI
import AVFoundation

@main
struct MuayThaiApp: App {
    init() {
        // Звук работает даже в беззвучном режиме
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
