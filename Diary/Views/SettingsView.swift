import SwiftUI

struct SettingsView: View {
    @ObservedObject var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var defaultEntryType: EntryType = .text
    @State private var showingTimePicker = false
    @State private var apiKey: String = ""
    @State private var showingAPIKeySheet = false
    @State private var apiKeyConfigured = false
    
    var body: some View {
        NavigationView {
            List {
                // Reminders Section
                Section("Daily Reminders") {
                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Reminders")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if notificationService.reminderEnabled {
                                Text("Reminder set for \(notificationService.reminderTime, formatter: timeFormatter)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { notificationService.reminderEnabled },
                            set: { newValue in
                                if newValue {
                                    // User wants to enable reminders
                                    if notificationService.isAuthorized {
                                        // Permission already granted
                                        notificationService.reminderEnabled = true
                                        notificationService.saveSettings()
                                        Task { await notificationService.scheduleReminder() }
                                    } else {
                                        // Need to request permission
                                        Task {
                                            await notificationService.requestPermission()
                                            await MainActor.run {
                                                if notificationService.isAuthorized {
                                                    notificationService.reminderEnabled = true
                                                    notificationService.saveSettings()
                                                    Task { await notificationService.scheduleReminder() }
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    // User wants to disable reminders
                                    notificationService.reminderEnabled = false
                                    notificationService.saveSettings()
                                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                                }
                            }
                        ))
                        .scaleEffect(0.9)
                    }
                    
                    if notificationService.reminderEnabled {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 14))
                            
                            Text("Reminder Time")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button(timeFormatter.string(from: notificationService.reminderTime)) {
                                showingTimePicker = true
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
                    }
                    
                    if !notificationService.isAuthorized && notificationService.reminderEnabled {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Permission Required")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                
                                Text("Grant notification permission in Settings")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Settings") {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // Preferences Section  
                Section("Preferences") {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                        
                        Text("Default Entry Type")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Picker("Default Type", selection: $defaultEntryType) {
                            ForEach(EntryType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .font(.caption)
                    }
                }
                
                // Speech to Text Section
                Section("Speech to Text") {
                    HStack {
                        Image(systemName: "waveform.and.mic")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("OpenAI API Key")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(apiKeyConfigured ? "Configured" : "Not configured")
                                .font(.caption2)
                                .foregroundColor(apiKeyConfigured ? .green : .orange)
                        }
                        
                        Spacer()
                        
                        Button(apiKeyConfigured ? "Update" : "Configure") {
                            showingAPIKeySheet = true
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transcribe your audio and video recordings using OpenAI's Whisper API.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 10))
                            
                            Text("Get your API key from platform.openai.com/account/api-keys")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Private Diary")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Your personal diary companion")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("v1.0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy First")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("All entries are saved locally and to your Notes app")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
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
        .sheet(isPresented: $showingTimePicker) {
            TimePickerView(
                selectedTime: $notificationService.reminderTime,
                onTimeChanged: { newTime in
                    notificationService.updateReminderTime(newTime)
                }
            )
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            APIKeyConfigurationView(
                apiKey: $apiKey,
                onSave: { key in
                    OpenAITranscriptionService.saveAPIKey(key)
                    apiKeyConfigured = true
                    apiKey = "" // Clear the field for security
                },
                onCancel: {
                    apiKey = ""
                }
            )
        }
        .onAppear {
            checkAPIKeyConfiguration()
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private func checkAPIKeyConfiguration() {
        let storedAPIKey = OpenAITranscriptionService.getStoredAPIKey()
        apiKeyConfigured = !storedAPIKey.isEmpty
    }
}

struct TimePickerView: View {
    @Binding var selectedTime: Date
    let onTimeChanged: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Select Reminder Time")
                    .font(.headline)
                    .padding()
                
                DatePicker(
                    "Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                
                Spacer()
            }
            .navigationTitle("Reminder Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onTimeChanged(selectedTime)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct APIKeyConfigurationView: View {
    @Binding var apiKey: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempAPIKey: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("Enter your OpenAI API key to enable speech-to-text transcription for audio and video recordings.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    TextField("sk-...", text: $tempAPIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        
                        Text("How to get your API key:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Go to platform.openai.com")
                        Text("2. Sign in to your account")
                        Text("3. Navigate to API Keys section")
                        Text("4. Create a new secret key")
                        Text("5. Copy and paste it here")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button("Save API Key") {
                        if !tempAPIKey.isEmpty {
                            onSave(tempAPIKey)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(tempAPIKey.isEmpty)
                    
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            }
            .navigationTitle("API Key Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            tempAPIKey = apiKey
        }
    }
}

#Preview {
    SettingsView(notificationService: NotificationService())
} 