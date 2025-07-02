import SwiftUI
import AVFoundation
import AVKit

struct HomeView: View {
    @StateObject private var diaryService = DiaryService()
    @StateObject private var notificationService = NotificationService()
    @State private var showingTextEntry = false
    @State private var showingAudioEntry = false
    @State private var showingVideoEntry = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daylink")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your personal diary companion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Start Entry Options
                VStack(spacing: 16) {
                    Text("Start Entry")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        EntryTypeButton(
                            type: .text,
                            action: { showingTextEntry = true }
                        )
                        
                        EntryTypeButton(
                            type: .audio,
                            action: { showingAudioEntry = true }
                        )
                        
                        EntryTypeButton(
                            type: .video,
                            action: { showingVideoEntry = true }
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Recent Entries
                if !diaryService.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Entries")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(diaryService.entries.count) entries")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(diaryService.entries.prefix(5)) { entry in
                                    EntryRow(entry: entry)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No entries yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Start by creating your first diary entry above")
                            .font(.subheadline)  
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $showingTextEntry) {
            TextEntryView(diaryService: diaryService)
        }
        .sheet(isPresented: $showingAudioEntry) {
            AudioEntryView(diaryService: diaryService)
        }
        .sheet(isPresented: $showingVideoEntry) {
            VideoEntryView(diaryService: diaryService)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(notificationService: notificationService)
        }
        .task {
            if !notificationService.isAuthorized {
                await notificationService.requestPermission()
            }
        }
    }
}

struct EntryTypeButton: View {
    let type: EntryType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.primary)
                
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EntryRow: View {
    let entry: DiaryEntry
    @State private var showingFullEntry = false
    @State private var showingAudioPlayer = false
    @State private var showingVideoPlayer = false
    
    var body: some View {
        Button {
            if entry.type == .audio && entry.audioURL != nil {
                showingAudioPlayer = true
            } else if entry.type == .video && entry.videoURL != nil {
                showingVideoPlayer = true
            } else {
                showingFullEntry = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: entry.type.icon)
                        .foregroundColor(.accentColor)
                    
                    Text(entry.title)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Media status indicator
                    if entry.type == .audio || entry.type == .video {
                        Image(systemName: "play.circle")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                    
                    Text(entry.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !entry.content.isEmpty {
                    Text(entry.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Media playback indicator
                if entry.type == .audio && entry.audioURL != nil {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("Tap to play audio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if entry.type == .video && entry.videoURL != nil {
                    HStack {
                        Image(systemName: "video")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("Tap to play video")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Mood indicator
                if let mood = entry.mood, !mood.isEmpty {
                    Text("Mood: \(mood)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingFullEntry) {
            FullEntryView(entry: entry)
        }
        .sheet(isPresented: $showingAudioPlayer) {
            AudioPlayerView(entry: entry)
        }
        .sheet(isPresented: $showingVideoPlayer) {
            VideoDiaryPlayerView(entry: entry)
        }
    }
}

struct FullEntryView: View {
    let entry: DiaryEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: entry.type.icon)
                                .foregroundColor(.accentColor)
                                .font(.title2)
                            
                            Text(entry.type.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(entry.formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(entry.title)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    // Content
                    if !entry.content.isEmpty {
                        Text(entry.content)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // Mood
                    if let mood = entry.mood, !mood.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mood")
                                .font(.headline)
                            Text(mood)
                                .font(.title)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Entry Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
} 