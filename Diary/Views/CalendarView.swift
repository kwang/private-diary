import SwiftUI

struct CalendarView: View {
    @ObservedObject var diaryService: DiaryService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showingEntriesForDate = false
    @State private var entriesForSelectedDate: [DiaryEntry] = []
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Month Navigation Header
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    
                    Spacer()
                    
                    Text(dateFormatter.string(from: currentMonth))
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal)
                
                // Days of Week Header
                HStack(spacing: 0) {
                    ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                        Text(weekday)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                
                // Calendar Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(getDaysInMonth(), id: \.self) { date in
                        CalendarDayView(
                            date: date,
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                            isToday: calendar.isDate(date, inSameDayAs: Date()),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            hasEntries: hasEntriesForDate(date),
                            entryCount: getEntryCountForDate(date)
                        ) {
                            selectedDate = date
                            entriesForSelectedDate = getEntriesForDate(date)
                            if !entriesForSelectedDate.isEmpty {
                                showingEntriesForDate = true
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Stats Section
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("This Month")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Text("\(getEntriesForMonth().count) entries")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Days Active")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Text("\(getActiveDaysThisMonth())")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    // Entry Type Breakdown
                    HStack(spacing: 12) {
                        ForEach(EntryType.allCases, id: \.self) { type in
                            let count = getEntryCountForTypeThisMonth(type)
                            if count > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 10))
                                        .foregroundColor(.accentColor)
                                    Text("\(count)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Calendar")
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
        .sheet(isPresented: $showingEntriesForDate) {
            DayEntriesView(
                date: selectedDate,
                entries: entriesForSelectedDate,
                diaryService: diaryService
            )
        }
        .onChange(of: showingEntriesForDate) { isPresented in
            if !isPresented {
                // Refresh entries when sheet is dismissed
                entriesForSelectedDate = getEntriesForDate(selectedDate)
            }
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
    
    private func getEntryCountForDate(_ date: Date) -> Int {
        return getEntriesForDate(date).count
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
    
    private func getEntryCountForTypeThisMonth(_ type: EntryType) -> Int {
        return getEntriesForMonth().filter { $0.type == type }.count
    }
}

struct CalendarDayView: View {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let hasEntries: Bool
    let entryCount: Int
    let onTap: () -> Void
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(dayFormatter.string(from: date))
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(textColor)
                
                // Entry indicator
                if hasEntries {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 32, height: 32)
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .secondary.opacity(0.5)
        } else if isSelected {
            return .white
        } else if isToday {
            return .accentColor
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .accentColor
        } else if isToday {
            return .accentColor.opacity(0.1)
        } else {
            return Color(.systemGray6).opacity(isCurrentMonth ? 1.0 : 0.3)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return .accentColor
        } else if isToday {
            return .accentColor.opacity(0.3)
        } else {
            return Color(.systemGray4)
        }
    }
    
    private var indicatorColor: Color {
        if isSelected {
            return .white
        } else {
            return .accentColor
        }
    }
}

struct DayEntriesView: View {
    let date: Date
    let entries: [DiaryEntry]
    let diaryService: DiaryService
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentEntries: [DiaryEntry] = []
    @State private var showingDeleteConfirmation = false
    @State private var entryToDelete: DiaryEntry?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Date Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateFormatter.string(from: date))
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("\(currentEntries.count) \(currentEntries.count == 1 ? "entry" : "entries")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Entries List
                    ForEach(currentEntries) { entry in
                        DayEntryRow(entry: entry) {
                            entryToDelete = entry
                            showingDeleteConfirmation = true
                        }
                        .padding(.horizontal)
                    }
                    
                    // Empty state
                    if currentEntries.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No entries for this day")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Entries you delete will be removed permanently.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Entries")
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
        .onAppear {
            currentEntries = entries
        }
        .confirmationDialog(
            "Delete Entry",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this diary entry? This action cannot be undone.")
        }
    }
    
    private func deleteEntry() {
        guard let entryToDelete = entryToDelete else { return }
        
        // Delete from the service
        diaryService.deleteEntry(entryToDelete)
        
        // Update local state
        currentEntries.removeAll { $0.id == entryToDelete.id }
        
        // Clear the entry to delete
        self.entryToDelete = nil
        
        // If no entries left, dismiss the sheet
        if currentEntries.isEmpty {
            dismiss()
        }
    }
}

// Custom entry row for the daily view with delete button
struct DayEntryRow: View {
    let entry: DiaryEntry
    let onDelete: () -> Void
    
    @State private var showingFullEntry = false
    @State private var showingAudioPlayer = false
    @State private var showingVideoPlayer = false
    
    var body: some View {
        // Main entry content with overlay delete button
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
                } else if entry.type == .photo, let photoURLs = entry.photoURLs, !photoURLs.isEmpty {
                    // Display first photo as thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        LocalImageView(url: photoURLs[0], isThumbnail: true)
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 60)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(.systemGray4), lineWidth: 0.5)
                            )
                            .padding(.leading, 18)
                        
                        if photoURLs.count > 1 {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.on.rectangle")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 10))
                                Text("+\(photoURLs.count - 1) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 18)
                        }
                    }
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
        .overlay(
            // Delete button positioned in bottom-right corner
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .frame(width: 20, height: 20)
                    .background(Color.white)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle()),
            alignment: .bottomTrailing
        )
        .padding(.trailing, 8)
        .padding(.bottom, 8)
        .sheet(isPresented: $showingFullEntry) {
            EntryDetailView(entry: entry)
        }
        .sheet(isPresented: $showingAudioPlayer) {
            AudioPlayerView(entry: entry)
        }
        .sheet(isPresented: $showingVideoPlayer) {
            VideoDiaryPlayerView(entry: entry)
        }
    }
}

// Simple entry detail view for the calendar
struct EntryDetailView: View {
    let entry: DiaryEntry
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoIndex: Int?
    @State private var showingPhotoViewer = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(photoURLs.indices, id: \.self) { index in
                                    LocalImageView(url: photoURLs[index])
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                                        )
                                        .onTapGesture {
                                            selectedPhotoIndex = index
                                            showingPhotoViewer = true
                                        }
                                }
                            }
                        }
                    }
                    
                    // Content
                    if !entry.content.isEmpty {
                        Text(entry.content)
                            .font(.callout)
                            .lineSpacing(4)
                    }
                    
                    // Mood
                    if let mood = entry.mood, !mood.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mood")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Text(mood)
                                .font(.callout)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Transcription
                    if let transcription = entry.transcription, !transcription.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transcription")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Text(transcription)
                                .font(.callout)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
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
        .sheet(isPresented: $showingPhotoViewer) {
            if let selectedPhotoIndex = selectedPhotoIndex,
               let photoURLs = entry.photoURLs,
               selectedPhotoIndex < photoURLs.count {
                PhotoViewerView(photoURLs: photoURLs, selectedIndex: selectedPhotoIndex)
            }
        }
    }
}



#Preview {
    CalendarView(diaryService: DiaryService())
} 