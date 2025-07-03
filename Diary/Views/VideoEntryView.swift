import SwiftUI
import AVFoundation
import UIKit

struct VideoEntryView: View {
    @ObservedObject var diaryService: DiaryService
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var videoRecorder = VideoRecorder()
    @StateObject private var transcriptionService = OpenAITranscriptionService.createWithStoredAPIKey()
    @State private var title = ""
    @State private var notes = ""
    @State private var mood = ""
    @State private var transcription = ""
    @State private var showingSaveAlert = false
    @State private var showingCamera = false
    @State private var showingAPIKeySheet = false
    
    private let moods = ["😊", "😔", "😤", "😌", "🤔", "😴", "🥳", "😰", "❤️", "🙄"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Title Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter title...", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.callout)
                }
                .padding(.horizontal)
                
                // Mood Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("How are you feeling? (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(moods, id: \.self) { emoji in
                                Button(emoji) {
                                    mood = mood == emoji ? "" : emoji
                                }
                                .font(.title3)
                                .frame(width: 38, height: 38)
                                .background(mood == emoji ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(mood == emoji ? Color.accentColor.opacity(0.3) : Color(.systemGray4), lineWidth: 0.5)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                
                // Video Recording Section
                VStack(spacing: 16) {
                    if let videoURL = videoRecorder.videoURL {
                        // Video Preview
                        VideoPlayerView(url: videoURL)
                            .frame(height: 180)
                            .cornerRadius(10)
                            .clipped()
                        
                        HStack(spacing: 12) {
                            Button("Record New") {
                                showingCamera = true
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            
                            Button("Use This Video") {
                                // Video is already saved, just continue
                            }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        // Record Button
                        VStack(spacing: 12) {
                            Image(systemName: "video.circle.fill")
                                .font(.system(size: 52))
                                .foregroundColor(.accentColor)
                            
                            Text("Record Video")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(UIImagePickerController.isSourceTypeAvailable(.camera) ? 
                                "Tap to start recording your video diary entry" : 
                                "Tap to select a video from your photo library")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(UIImagePickerController.isSourceTypeAvailable(.camera) ? 
                                  "Start Recording" : "Select Video") {
                                showingCamera = true
                            }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .disabled(!videoRecorder.hasPermission)
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                        
                        if !videoRecorder.hasPermission {
                            VStack(spacing: 6) {
                                Text(UIImagePickerController.isSourceTypeAvailable(.camera) ?
                                    "Camera access required" : "Photo library access required")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                
                                Button("Grant Permission") {
                                    videoRecorder.requestPermission()
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Transcription Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Speech to Text")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        if videoRecorder.videoURL != nil {
                            Button {
                                Task {
                                    await transcribeVideo()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if transcriptionService.isTranscribing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "waveform.and.mic")
                                            .font(.caption)
                                    }
                                    Text(transcriptionService.isTranscribing ? "Transcribing..." : "Transcribe")
                                        .font(.caption)
                                }
                            }
                            .disabled(transcriptionService.isTranscribing)
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    if !transcription.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transcription:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text(transcription)
                                .font(.callout)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                            
                            HStack {
                                Button("Use as Notes") {
                                    notes = transcription
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                                
                                Button("Copy") {
                                    UIPasteboard.general.string = transcription
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    if let error = transcriptionService.transcriptionError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal)
                
                // Notes Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional Notes (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                            .frame(minHeight: 90)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 0.5)
                            )
                        
                        Group {
                            if #available(iOS 16.0, *) {
                                TextEditor(text: $notes)
                                    .scrollContentBackground(.hidden)
                            } else {
                                TextEditor(text: $notes)
                            }
                        }
                        .padding(12)
                        .background(Color.clear)
                        .font(.callout)
                        
                        if notes.isEmpty {
                            Text("Any additional thoughts to accompany your video?")
                                .foregroundColor(.secondary)
                                .font(.callout)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Save Button
                Button {
                    saveEntry()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                        Text("Save Entry")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(videoRecorder.videoURL == nil)
                .opacity(videoRecorder.videoURL == nil ? 0.6 : 1.0)
            }
            .navigationTitle("New Video Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline)
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(videoRecorder: videoRecorder)
        }
        .onAppear {
            title = "Video Diary - \(DateFormatter.entryFormatter.string(from: Date()))"
            videoRecorder.requestPermission()
        }
        .alert("Entry Saved!", isPresented: $showingSaveAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your video diary entry has been saved to local files.")
        }
        .alert("OpenAI API Key Required", isPresented: $showingAPIKeySheet) {
            Button("Cancel", role: .cancel) { }
            Button("Go to Settings") {
                // Navigate to settings or show instructions
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
        } message: {
            Text("To use speech-to-text transcription, please configure your OpenAI API key in the Settings.")
        }
    }
    
    private func saveEntry() {
        var entry = DiaryEntry(type: .video, title: title, content: notes)
        entry.mood = mood.isEmpty ? nil : mood
        entry.transcription = transcription.isEmpty ? nil : transcription
        
        // Save video file to persistent storage
        if let tempURL = videoRecorder.videoURL {
            entry.videoURL = diaryService.saveVideoFile(tempURL)
            
            // Clean up temporary video file after copying
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        diaryService.saveEntry(entry)
        showingSaveAlert = true
    }
    
    private func transcribeVideo() async {
        guard let videoURL = videoRecorder.videoURL else { return }
        
        // Check if API key is configured
        if OpenAITranscriptionService.getStoredAPIKey().isEmpty {
            showingAPIKeySheet = true
            return
        }
        
        if let result = await transcriptionService.transcribeVideo(fileURL: videoURL) {
            transcription = result
        }
    }
}

@MainActor
class VideoRecorder: ObservableObject {
    @Published var hasPermission = false
    @Published var videoURL: URL?
    
    init() {
        requestPermission()
    }
    
    func requestPermission() {
        // Request camera permission if camera is available
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                }
            }
        } else {
            // In simulator, just set permission to true since we'll use photo library
            DispatchQueue.main.async {
                self.hasPermission = true
            }
        }
    }
    
    func saveVideo(url: URL) {
        self.videoURL = url
    }
}

struct CameraView: UIViewControllerRepresentable {
    @ObservedObject var videoRecorder: VideoRecorder
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        
        // Check if camera is available (not in simulator)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            // Fallback to photo library for simulator testing
            picker.sourceType = .photoLibrary
        }
        
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeMedium
        picker.videoMaximumDuration = 300 // 5 minutes max
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.videoRecorder.saveVideo(url: videoURL)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct VideoPlayerView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> UIView {
        return VideoPlayerUIView(url: url)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

class VideoPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    
    init(url: URL) {
        super.init(frame: .zero)
        
        let player = AVPlayer(url: url)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
        
        // Add play button overlay
        let playButton = UIButton(type: .system)
        playButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        playButton.tintColor = .white
        playButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        playButton.layer.cornerRadius = 25
        playButton.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(playButton)
        
        NSLayoutConstraint.activate([
            playButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 50),
            playButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        playButton.addTarget(self, action: #selector(playVideo), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
    
    @objc private func playVideo() {
        playerLayer.player?.play()
    }
}

#Preview {
    VideoEntryView(diaryService: DiaryService())
} 