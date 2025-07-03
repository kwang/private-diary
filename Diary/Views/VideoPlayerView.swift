import SwiftUI
import AVFoundation
import AVKit

struct VideoDiaryPlayerView: View {
    let entry: DiaryEntry
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "video.circle.fill")
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
                
                // Video Player
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(height: 300)
                        .cornerRadius(16)
                        .onAppear {
                            player.play()
                        }
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray5))
                        .frame(height: 300)
                        .overlay(
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                                Text("Video not available")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        )
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
            .navigationTitle("Video Diary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        shareVideo()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(entry.videoURL == nil)
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private func setupPlayer() {
        guard let videoURL = entry.videoURL else { 
            print("No video URL found for entry: \(entry.title)")
            return 
        }
        
        // Check if file exists first
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("Video file not found at: \(videoURL.path)")
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = AVPlayer(url: videoURL)
            print("Video player setup successfully for URL: \(videoURL)")
        } catch {
            print("Failed to setup video player: \(error)")
        }
    }
    
    private func shareVideo() {
        guard let videoURL = entry.videoURL else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [videoURL],
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

#Preview {
    VideoDiaryPlayerView(entry: DiaryEntry(type: .video, title: "Sample Video Entry", content: "This is a test video entry"))
} 