import SwiftUI
import AVFoundation

struct AudioEntryView: View {
    @ObservedObject var diaryService: DiaryService
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var transcriptionService = OpenAITranscriptionService.createWithStoredAPIKey()
    @State private var title = ""
    @State private var notes = ""
    @State private var mood = ""
    @State private var transcription = ""
    @State private var showingSaveAlert = false
    @State private var showingPermissionAlert = false
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
                
                // Audio Recording Section
                VStack(spacing: 16) {
                    // Recording Status
                    VStack(spacing: 6) {
                        if audioRecorder.isRecording {
                            Text("Recording...")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            
                            Text(audioRecorder.formattedTime)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        } else if audioRecorder.hasRecording {
                            Text("Recording Complete")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                            
                            Text(audioRecorder.formattedTime)
                                .font(.title3)
                                .fontWeight(.semibold)
                        } else {
                            Text("Ready to Record")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Recording Controls
                    HStack(spacing: 28) {
                        // Record/Stop Button
                        Button {
                            if audioRecorder.isRecording {
                                audioRecorder.stopRecording()
                            } else {
                                audioRecorder.startRecording()
                            }
                        } label: {
                            Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(audioRecorder.isRecording ? .red : .accentColor)
                        }
                        .disabled(!audioRecorder.hasPermission)
                        
                        // Play Button (only show if has recording and not recording)
                        if audioRecorder.hasRecording && !audioRecorder.isRecording {
                            Button {
                                audioRecorder.playRecording()
                            } label: {
                                Image(systemName: audioRecorder.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    // Permission Status
                    if !audioRecorder.hasPermission {
                        VStack(spacing: 6) {
                            Text("Microphone access required")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            
                            Button("Grant Permission") {
                                audioRecorder.requestPermission()
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
                .padding(.horizontal)
                
                // Transcription Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Speech to Text")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        if audioRecorder.hasRecording {
                            Button {
                                Task {
                                    await transcribeAudio()
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
                            Text("Any additional thoughts to accompany your recording?")
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
                .disabled(!audioRecorder.hasRecording)
                .opacity(!audioRecorder.hasRecording ? 0.6 : 1.0)
            }
            .navigationTitle("New Audio Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if audioRecorder.isRecording {
                            audioRecorder.stopRecording()
                        }
                        dismiss()
                    }
                    .font(.subheadline)
                }
            }
        }
        .onAppear {
            title = "Audio Diary - \(DateFormatter.entryFormatter.string(from: Date()))"
            audioRecorder.requestPermission()
        }
        .alert("Entry Saved!", isPresented: $showingSaveAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your audio diary entry has been saved to local files.")
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
        var entry = DiaryEntry(type: .audio, title: title, content: notes)
        entry.mood = mood.isEmpty ? nil : mood
        entry.transcription = transcription.isEmpty ? nil : transcription
        
        // Save audio file to persistent storage
        if let tempURL = audioRecorder.recordingURL {
            entry.audioURL = diaryService.saveAudioFile(tempURL)
            
            // Clean up temporary recording file after copying
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        diaryService.saveEntry(entry)
        showingSaveAlert = true
    }
    
    private func transcribeAudio() async {
        guard let audioURL = audioRecorder.recordingURL else { return }
        
        // Check if API key is configured
        if OpenAITranscriptionService.getStoredAPIKey().isEmpty {
            showingAPIKeySheet = true
            return
        }
        
        if let result = await transcriptionService.transcribeAudio(fileURL: audioURL) {
            transcription = result
        }
    }
}

@MainActor
class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var hasRecording = false
    @Published var hasPermission = false
    @Published var recordingTime: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var currentRecordingURL: URL?
    
    var recordingURL: URL? {
        return currentRecordingURL
    }
    
    var formattedTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init() {
        requestPermission()
    }
    
    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
            }
        }
    }
    
    func startRecording() {
        guard hasPermission else { return }
        
        // Create a unique filename for this recording
        let timestamp = Date().timeIntervalSince1970
        let fileName = "temp_recording_\(timestamp).m4a"
        currentRecordingURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: currentRecordingURL!, settings: settings)
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            hasRecording = false // Reset until recording is complete
            
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                self.recordingTime += 1
            }
            
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        hasRecording = true
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    func playRecording() {
        guard let url = recordingURL, FileManager.default.fileExists(atPath: url.path) else { 
            print("Recording file not found at: \(recordingURL?.path ?? "nil")")
            return 
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = AudioRecorderDelegate(recorder: self)
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Failed to play recording: \(error)")
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

class AudioRecorderDelegate: NSObject, AVAudioPlayerDelegate {
    let recorder: AudioRecorder
    
    init(recorder: AudioRecorder) {
        self.recorder = recorder
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            recorder.isPlaying = false
        }
    }
}

#Preview {
    AudioEntryView(diaryService: DiaryService())
} 