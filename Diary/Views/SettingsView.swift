import SwiftUI

struct SettingsView: View {
    @ObservedObject var notificationService: NotificationService
    @ObservedObject var diaryService: DiaryService
    @State private var showingRecoveryAlert = false
    @State private var showingSyncAlert = false
    @State private var showingDownloadAlert = false
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var syncDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        NavigationView {
            Form {
                // App Info
                Section {
                    HStack {
                        Image(systemName: "book.pages")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Private Diary")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Your personal diary companion")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                // Notifications
                Section("Notifications") {
                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        
                        Text("Daily Reminders")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { notificationService.reminderEnabled },
                            set: { _ in notificationService.toggleReminder() }
                        ))
                        .scaleEffect(0.9)
                    }
                    
                    if notificationService.reminderEnabled {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            
                            Text("Reminder Time")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            DatePicker("", selection: Binding(
                                get: { notificationService.reminderTime },
                                set: { newTime in notificationService.updateReminderTime(newTime) }
                            ), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        }
                    }
                }
                
                // File Recovery
                FileRecoverySection(diaryService: diaryService, showingRecoveryAlert: $showingRecoveryAlert)
                
                // iCloud Sync (Simulator Only)
                #if targetEnvironment(simulator)
                CloudSyncSection(diaryService: diaryService, showingSyncAlert: $showingSyncAlert, showingDownloadAlert: $showingDownloadAlert, syncDateFormatter: syncDateFormatter)
                #else
                // Device Info
                Section("Sync Information") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iCloud Sync Not Available")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("iCloud sync is only available when running in the simulator. On device, your entries are saved locally.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                #endif
                
                // About
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading) {
                            Text("Private Diary")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Version 1.0")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Files Recovered", isPresented: $showingRecoveryAlert) {
            Button("OK") { }
        } message: {
            Text("Attempted to recover missing files. Check the file recovery section for current status.")
        }
        .alert("Sync Complete", isPresented: $showingSyncAlert) {
            Button("OK") { }
        } message: {
            Text("Manual sync completed successfully.")
        }
        .alert("Download Complete", isPresented: $showingDownloadAlert) {
            Button("OK") { }
        } message: {
            Text("Downloaded entries from iCloud successfully.")
        }
    }
}

struct FileRecoverySection: View {
    @ObservedObject var diaryService: DiaryService
    @Binding var showingRecoveryAlert: Bool
    
    var body: some View {
        let missingCounts = diaryService.missingFileStats
        let totalMissing = missingCounts.audio + missingCounts.video + missingCounts.photos
        
        Section(header: Text("File Recovery")) {
            if totalMissing == 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All media files are accessible")
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Missing Files Found")
                            .fontWeight(.medium)
                    }
                    
                    if missingCounts.audio > 0 {
                        Text("• \(missingCounts.audio) missing audio file(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if missingCounts.video > 0 {
                        Text("• \(missingCounts.video) missing video file(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if missingCounts.photos > 0 {
                        Text("• \(missingCounts.photos) missing photo file(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Recover Missing Files") {
                        diaryService.recoverAllMissingFiles()
                        showingRecoveryAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
            
            Text("The app automatically recovers missing files when it starts. This can happen after app updates or device restores.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CloudSyncSection: View {
    @ObservedObject var diaryService: DiaryService
    @Binding var showingSyncAlert: Bool
    @Binding var showingDownloadAlert: Bool
    let syncDateFormatter: DateFormatter
    
    var body: some View {
        Section("iCloud Sync") {
            // Account Status
            HStack {
                Image(systemName: diaryService.canUseiCloud ? "icloud.fill" : "icloud.slash")
                    .foregroundColor(diaryService.canUseiCloud ? .blue : .gray)
                    .font(.system(size: 14))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Account")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(diaryService.canUseiCloud ? "Connected" : "Not Connected")
                        .font(.caption2)
                        .foregroundColor(diaryService.canUseiCloud ? .green : .secondary)
                }
                
                Spacer()
            }
            
            // Sync Toggle
            if diaryService.canUseiCloud {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    
                    Text("Automatic Sync")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { diaryService.iCloudSyncEnabled },
                        set: { enabled in diaryService.setiCloudSyncEnabled(enabled) }
                    ))
                    .scaleEffect(0.9)
                }
                
                // Manual Sync Actions
                if diaryService.iCloudSyncEnabled {
                    HStack {
                        Button {
                            Task {
                                await diaryService.triggerManualSync()
                                showingSyncAlert = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.system(size: 12))
                                Text("Upload to iCloud")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                        
                        Button {
                            Task {
                                await diaryService.downloadFromiCloud()
                                showingDownloadAlert = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "icloud.and.arrow.down")
                                    .font(.system(size: 12))
                                Text("Download from iCloud")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            // Information
            Text("Your diary entries will be securely stored in your private iCloud account and synced across all your devices.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView(notificationService: NotificationService(), diaryService: DiaryService())
} 