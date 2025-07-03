import SwiftUI
import AVFoundation
import AVKit

struct HomeView: View {
    @StateObject private var diaryService = DiaryService()
    @StateObject private var notificationService = NotificationService()
    @State private var showingTextEntry = false
    @State private var showingAudioEntry = false
    @State private var showingVideoEntry = false
    @State private var showingPhotoEntry = false
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
                        
                        EntryTypeButton(
                            type: .photo,
                            action: { showingPhotoEntry = true }
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
                            ForEach(diaryService.entries.prefix(3)) { entry in
                                EntryRow(entry: entry)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .padding(.vertical, 2)
                            }
                            .onDelete(perform: deleteEntries)
                        }
                        .listStyle(PlainListStyle())
                        .frame(maxHeight: 200)
                    }
                    
                    // Calendar Overview
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Calendar Overview")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button("View All") {
                                showingCalendar = true
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal)
                        
                        CompactCalendarView(diaryService: diaryService)
                            .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 32))
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
                        
                        // Calendar Overview (even when empty)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Calendar Overview")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Button("View All") {
                                    showingCalendar = true
                                }
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            }
                            .padding(.horizontal)
                            
                            CompactCalendarView(diaryService: diaryService)
                                .padding(.horizontal)
                        }
                    }
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
        .sheet(isPresented: $showingPhotoEntry) {
            PhotoEntryView(diaryService: diaryService)
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
                        } else if entry.type == .photo {
                            Image(systemName: "photo.fill")
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
                } else if entry.type == .photo && entry.photoURLs != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                        Text("\(entry.photoURLs?.count ?? 0) photo(s)")
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
                    
                    // Photos (for photo entries)
                    if entry.type == .photo, let photoURLs = entry.photoURLs, !photoURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Photos")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .modifier(TrackingModifier())
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(photoURLs.indices, id: \.self) { index in
                                    AsyncImage(url: photoURLs[index]) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(.systemGray5))
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.secondary)
                                            )
                                    }
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                                    )
                                }
                            }
                        }
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

struct CompactCalendarView: View {
    @ObservedObject var diaryService: DiaryService
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var showingEntriesForDate = false
    @State private var entriesForSelectedDate: [DiaryEntry] = []
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 12) {
            // Month Header
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: currentMonth))
                    .font(.callout)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }
            
            // Compact Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                // Days of week header
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                    Text(String(weekday.prefix(1)))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 20)
                }
                
                // Calendar days
                ForEach(getDaysInMonth(), id: \.self) { date in
                    CompactCalendarDayView(
                        date: date,
                        isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                        isToday: calendar.isDate(date, inSameDayAs: Date()),
                        hasEntries: hasEntriesForDate(date)
                    ) {
                        // Handle tap on calendar day
                        selectedDate = date
                        entriesForSelectedDate = getEntriesForDate(date)
                        if !entriesForSelectedDate.isEmpty {
                            showingEntriesForDate = true
                        }
                    }
                }
            }
            
            // Quick stats
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("\(getEntriesForMonth().count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("entries")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Text("\(getActiveDaysThisMonth())")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("active days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .sheet(isPresented: $showingEntriesForDate) {
            DayEntriesView(
                date: selectedDate,
                entries: entriesForSelectedDate
            )
        }
    }
    
    // MARK: - Helper Functions
    private func getDaysInMonth() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        
        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let daysFromPreviousMonth = firstWeekday - 1
        
        var days: [Date] = []
        
        // Add days from previous month
        for i in 0..<daysFromPreviousMonth {
            if let date = calendar.date(byAdding: .day, value: -daysFromPreviousMonth + i, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Add days from current month
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Add days from next month to fill grid (42 total days)
        while days.count < 42 {
            if let lastDate = days.last,
               let nextDate = calendar.date(byAdding: .day, value: 1, to: lastDate) {
                days.append(nextDate)
            } else {
                break
            }
        }
        
        return days
    }
    
    private func hasEntriesForDate(_ date: Date) -> Bool {
        return !getEntriesForDate(date).isEmpty
    }
    
    private func getEntriesForDate(_ date: Date) -> [DiaryEntry] {
        return diaryService.entries.filter { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
    }
    
    private func getEntriesForMonth() -> [DiaryEntry] {
        return diaryService.entries.filter { entry in
            calendar.isDate(entry.date, equalTo: currentMonth, toGranularity: .month)
        }
    }
    
    private func getActiveDaysThisMonth() -> Int {
        let monthEntries = getEntriesForMonth()
        let uniqueDays = Set(monthEntries.map { calendar.startOfDay(for: $0.date) })
        return uniqueDays.count
    }
}

struct CompactCalendarDayView: View {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let hasEntries: Bool
    let onTap: () -> Void
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text(dayFormatter.string(from: date))
                    .font(.caption2)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(textColor)
                
                // Entry indicator
                Circle()
                    .fill(hasEntries ? .accentColor : Color.clear)
                    .frame(width: 3, height: 3)
            }
            .frame(width: 24, height: 24)
            .background(backgroundColor)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .secondary.opacity(0.4)
        } else if isToday {
            return .accentColor
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isToday {
            return .accentColor.opacity(0.1)
        } else {
            return Color.clear
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