import SwiftUI
import AVFoundation

struct AudioPlayerView: View {
    let entry: DiaryEntry
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer = AudioPlayerManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                    
                    VStack(spacing: 8) {
                        Text(entry.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(entry.formattedDate)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Waveform visualization placeholder
                VStack(spacing: 16) {
                    // Audio duration and progress
                    if audioPlayer.duration > 0 {
                        VStack(spacing: 8) {
                            HStack {
                                Text(timeString(from: audioPlayer.currentTime))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(timeString(from: audioPlayer.duration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: audioPlayer.progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                        }
                        .padding(.horizontal)
                    }
                    
                    // Waveform visualization
                    HStack(spacing: 4) {
                        ForEach(0..<25, id: \.self) { index in
                            Rectangle()
                                .fill(audioPlayer.isPlaying ? Color.accentColor : Color.secondary)
                                .frame(width: 3, height: CGFloat.random(in: 20...60))
                                .animation(.easeInOut(duration: 0.5).repeatForever(), value: audioPlayer.isPlaying)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Playback controls or error state
                if !audioPlayer.canPlay && entry.audioURL != nil {
                    // Show error state if audio URL exists but can't be played
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Audio file not found")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("This audio recording may have been removed or corrupted.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    // Normal playback controls
                    HStack(spacing: 40) {
                        Button {
                            audioPlayer.skipBackward()
                        } label: {
                            Image(systemName: "gobackward.15")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        .disabled(!audioPlayer.canPlay)
                        
                        Button {
                            if audioPlayer.isPlaying {
                                audioPlayer.pause()
                            } else {
                                audioPlayer.play()
                            }
                        } label: {
                            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.accentColor)
                        }
                        .disabled(!audioPlayer.canPlay)
                        
                        Button {
                            audioPlayer.skipForward()
                        } label: {
                            Image(systemName: "goforward.15")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        .disabled(!audioPlayer.canPlay)
                    }
                }
                
                // Additional notes
                if !entry.content.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        
                        Text(entry.content)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
                
                // Mood
                if let mood = entry.mood, !mood.isEmpty {
                    HStack {
                        Text("Mood:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(mood)
                            .font(.title2)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Audio Diary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        audioPlayer.stop()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        shareAudio()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(!audioPlayer.canPlay)
                }
            }
        }
        .onAppear {
            if let audioURL = entry.audioURL {
                audioPlayer.loadAudio(from: audioURL)
            } else {
                print("No audio URL found for entry: \(entry.title)")
            }
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func shareAudio() {
        guard let audioURL = entry.audioURL else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [audioURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = topController.view
                popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topController.present(activityViewController, animated: true)
        }
    }
}

@MainActor
class AudioPlayerManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var canPlay = false
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    func loadAudio(from url: URL) {
        // Check if file exists first
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Audio file not found at: \(url.path)")
            canPlay = false
            return
        }
        
        do {
            // Configure audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = AudioPlayerDelegate(manager: self)
            audioPlayer?.prepareToPlay()
            
            duration = audioPlayer?.duration ?? 0
            canPlay = true
            
            print("Audio loaded successfully. Duration: \(duration)")
        } catch {
            print("Failed to load audio: \(error)")
            canPlay = false
        }
    }
    
    func play() {
        guard let player = audioPlayer else { return }
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
            startTimer()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopTimer()
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    func skipForward() {
        guard let player = audioPlayer else { return }
        let newTime = min(player.currentTime + 15, player.duration)
        player.currentTime = newTime
        currentTime = newTime
    }
    
    func skipBackward() {
        guard let player = audioPlayer else { return }
        let newTime = max(player.currentTime - 15, 0)
        player.currentTime = newTime
        currentTime = newTime
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateProgress() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
        
        if !player.isPlaying {
            isPlaying = false
            stopTimer()
        }
    }
    
    func audioDidFinishPlaying() {
        isPlaying = false
        currentTime = 0
        audioPlayer?.currentTime = 0
        stopTimer()
    }
}

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    weak var manager: AudioPlayerManager?
    
    init(manager: AudioPlayerManager) {
        self.manager = manager
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            manager?.audioDidFinishPlaying()
        }
    }
}

#Preview {
    AudioPlayerView(entry: DiaryEntry(type: .audio, title: "Sample Audio Entry", content: "This is a test audio entry"))
} 