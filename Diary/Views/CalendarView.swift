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
    @Environment(\.dismiss) private var dismiss
    
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
                        
                        Text("\(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Entries List
                    ForEach(entries) { entry in
                        EntryRow(entry: entry)
                            .padding(.horizontal)
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
    }
}

#Preview {
    CalendarView(diaryService: DiaryService())
} 