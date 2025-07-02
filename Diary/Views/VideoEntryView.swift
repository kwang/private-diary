import SwiftUI
import AVFoundation
import UIKit

struct VideoEntryView: View {
    @ObservedObject var diaryService: DiaryService
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var videoRecorder = VideoRecorder()
    @State private var title = ""
    @State private var notes = ""
    @State private var mood = ""
    @State private var showingSaveAlert = false
    @State private var showingCamera = false
    
    private let moods = ["😊", "😔", "😤", "😌", "🤔", "😴", "🥳", "😰", "❤️", "🙄"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Title Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.headline)
                    
                    TextField("Enter title...", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Mood Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("How are you feeling? (Optional)")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(moods, id: \.self) { emoji in
                                Button(emoji) {
                                    mood = mood == emoji ? "" : emoji
                                }
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(mood == emoji ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Video Recording Section
                VStack(spacing: 20) {
                    if let videoURL = videoRecorder.videoURL {
                        // Video Preview
                        VideoPlayerView(url: videoURL)
                            .frame(height: 200)
                            .cornerRadius(12)
                            .clipped()
                        
                        HStack(spacing: 16) {
                            Button("Record New") {
                                showingCamera = true
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Use This Video") {
                                // Video is already saved, just continue
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        // Record Button
                        VStack(spacing: 16) {
                            Image(systemName: "video.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.accentColor)
                            
                            Text("Record Video")
                                .font(.headline)
                            
                            Text(UIImagePickerController.isSourceTypeAvailable(.camera) ? 
                                "Tap to start recording your video diary entry" : 
                                "Tap to select a video from your photo library")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(UIImagePickerController.isSourceTypeAvailable(.camera) ? 
                                  "Start Recording" : "Select Video") {
                                showingCamera = true
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!videoRecorder.hasPermission)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        
                        if !videoRecorder.hasPermission {
                            VStack(spacing: 8) {
                                Text(UIImagePickerController.isSourceTypeAvailable(.camera) ?
                                    "Camera access required" : "Photo library access required")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                
                                Button("Grant Permission") {
                                    videoRecorder.requestPermission()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Notes Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional Notes (Optional)")
                        .font(.headline)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(minHeight: 100)
                        
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
                        .font(.body)
                        
                        if notes.isEmpty {
                            Text("Any additional thoughts to accompany your video?")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
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
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save to Notes")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(videoRecorder.videoURL == nil)
            }
            .navigationTitle("New Video Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
            Text("Your video diary entry has been saved and will be shared to Notes.")
        }
    }
    
    private func saveEntry() {
        var entry = DiaryEntry(type: .video, title: title, content: notes)
        entry.mood = mood.isEmpty ? nil : mood
        
        // Save video file to persistent storage
        if let tempURL = videoRecorder.videoURL {
            entry.videoURL = diaryService.saveVideoFile(tempURL)
        }
        
        diaryService.saveEntry(entry)
        showingSaveAlert = true
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