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
    @State private var showingCalendar = false
    @State private var editMode: EditMode = .inactive
    @State private var showingDeleteAlert = false
    @State private var entriesToDelete: IndexSet?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Private Diary")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Your personal diary companion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Start Entry Options
                VStack(spacing: 12) {
                    Text("Start Entry")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
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
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Entries")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(diaryService.entries.count) entries")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Button(editMode == .inactive ? "Edit" : "Done") {
                                withAnimation {
                                    editMode = editMode == .inactive ? .active : .inactive
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal)
                        
                        List {
                            ForEach(diaryService.entries.prefix(10)) { entry in
                                EntryRow(entry: entry)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .padding(.vertical, 2)
                            }
                            .onDelete(perform: deleteEntries)
                        }
                        .listStyle(PlainListStyle())
                        .frame(maxHeight: 350)
                    }
                } else {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        
                        Text("No entries yet")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Start by creating your first diary entry above")
                            .font(.caption)  
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                    }
                }
            }
            .environment(\.editMode, $editMode)
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
        .sheet(isPresented: $showingCalendar) {
            CalendarView(diaryService: diaryService)
        }
        .task {
            if !notificationService.isAuthorized {
                await notificationService.requestPermission()
            }
        }
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                entriesToDelete = nil
            }
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text("Are you sure you want to delete this diary entry? This action cannot be undone.")
        }
    }
    
    // MARK: - Delete Functions
    private func deleteEntries(at offsets: IndexSet) {
        entriesToDelete = offsets
        showingDeleteAlert = true
    }
    
    private func confirmDelete() {
        guard let offsets = entriesToDelete else { return }
        withAnimation {
            for index in offsets {
                let entry = diaryService.entries[index]
                diaryService.deleteEntry(entry)
            }
        }
        entriesToDelete = nil
    }
}

struct EntryTypeButton: View {
    let type: EntryType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
                
                Text(type.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
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
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Image(systemName: entry.type.icon)
                        .foregroundColor(.accentColor)
                        .font(.system(size: 14))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        if !entry.content.isEmpty {
                            Text(entry.content)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        // Media status indicator
                        if entry.type == .audio || entry.type == .video {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 12))
                        }
                        
                        Text(entry.timeAgo)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Media playback indicator
                if entry.type == .audio && entry.audioURL != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                        Text("Tap to play audio")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 18)
                } else if entry.type == .video && entry.videoURL != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                        Text("Tap to play video")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 18)
                }
                
                // Mood indicator
                if let mood = entry.mood, !mood.isEmpty {
                    HStack(spacing: 4) {
                        Text(mood)
                            .font(.caption2)
                        Text("mood")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 18)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
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
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: entry.type.icon)
                                .foregroundColor(.accentColor)
                                .font(.system(size: 16))
                            
                            Text(entry.type.rawValue)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .modifier(TrackingModifier())
                            
                            Spacer()
                            
                            Text(entry.formattedDate)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(entry.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    // Content
                    if !entry.content.isEmpty {
                        Text(entry.content)
                            .font(.callout)
                            .lineSpacing(2)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 0.5)
                            )
                    }
                    
                    // Mood
                    if let mood = entry.mood, !mood.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mood")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .modifier(TrackingModifier())
                            HStack(spacing: 6) {
                                Text(mood)
                                    .font(.title2)
                                Text("feeling")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
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
                    .font(.subheadline)
                }
            }
        }
    }
}

struct TrackingModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.tracking(0.5)
        } else {
            content
        }
    }
}

#Preview {
    HomeView()
} 