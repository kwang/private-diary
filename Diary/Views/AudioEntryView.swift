import SwiftUI
import AVFoundation

struct AudioEntryView: View {
    @ObservedObject var diaryService: DiaryService
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var title = ""
    @State private var notes = ""
    @State private var mood = ""
    @State private var showingSaveAlert = false
    @State private var showingPermissionAlert = false
    
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
                
                // Audio Recording Section
                VStack(spacing: 20) {
                    // Recording Status
                    VStack(spacing: 8) {
                        if audioRecorder.isRecording {
                            Text("Recording...")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text(audioRecorder.formattedTime)
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        } else if audioRecorder.hasRecording {
                            Text("Recording Complete")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            Text(audioRecorder.formattedTime)
                                .font(.title2)
                                .fontWeight(.medium)
                        } else {
                            Text("Ready to Record")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Recording Controls
                    HStack(spacing: 32) {
                        // Record/Stop Button
                        Button {
                            if audioRecorder.isRecording {
                                audioRecorder.stopRecording()
                            } else {
                                audioRecorder.startRecording()
                            }
                        } label: {
                            Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(audioRecorder.isRecording ? .red : .accentColor)
                        }
                        .disabled(!audioRecorder.hasPermission)
                        
                        // Play Button (only show if has recording and not recording)
                        if audioRecorder.hasRecording && !audioRecorder.isRecording {
                            Button {
                                audioRecorder.playRecording()
                            } label: {
                                Image(systemName: audioRecorder.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    // Permission Status
                    if !audioRecorder.hasPermission {
                        VStack(spacing: 8) {
                            Text("Microphone access required")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Button("Grant Permission") {
                                audioRecorder.requestPermission()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Notes Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional Notes (Optional)")
                        .font(.headline)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(minHeight: 100)
                        
                        TextEditor(text: $notes)
                            .padding(12)
                            .background(Color.clear)
                            .scrollContentBackground(.hidden)
                            .font(.body)
                        
                        if notes.isEmpty {
                            Text("Any additional thoughts to accompany your recording?")
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
                .disabled(!audioRecorder.hasRecording)
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
            Text("Your audio diary entry has been saved and will be shared to Notes.")
        }
    }
    
    private func saveEntry() {
        var entry = DiaryEntry(type: .audio, title: title, content: notes)
        entry.mood = mood.isEmpty ? nil : mood
        
        // Save audio file to persistent storage
        if let tempURL = audioRecorder.recordingURL {
            entry.audioURL = diaryService.saveAudioFile(tempURL)
        }
        
        diaryService.saveEntry(entry)
        showingSaveAlert = true
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
    
    var recordingURL: URL? {
        getDocumentsDirectory().appendingPathComponent("recording.m4a")
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
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.hasPermission = granted
            }
        }
    }
    
    func startRecording() {
        guard hasPermission else { return }
        
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
            
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            
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
        guard let url = recordingURL else { return }
        
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