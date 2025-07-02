import SwiftUI

struct SettingsView: View {
    @ObservedObject var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var defaultEntryType: EntryType = .text
    @State private var showingTimePicker = false
    
    var body: some View {
        NavigationView {
            List {
                // Reminders Section
                Section("Daily Reminders") {
                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text("Enable Reminders")
                                .font(.headline)
                            
                            if notificationService.reminderEnabled {
                                Text("Reminder set for \(notificationService.reminderTime, formatter: timeFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(notificationService.reminderEnabled))
                            .onTapGesture {
                                if notificationService.isAuthorized {
                                    notificationService.toggleReminder()
                                } else {
                                    Task {
                                        await notificationService.requestPermission()
                                    }
                                }
                            }
                    }
                    
                    if notificationService.reminderEnabled {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.accentColor)
                            
                            Text("Reminder Time")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(timeFormatter.string(from: notificationService.reminderTime)) {
                                showingTimePicker = true
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                    
                    if !notificationService.isAuthorized && notificationService.reminderEnabled {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading) {
                                Text("Permission Required")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                
                                Text("Grant notification permission in Settings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Settings") {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // Preferences Section  
                Section("Preferences") {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .foregroundColor(.accentColor)
                        
                        Text("Default Entry Type")
                            .font(.headline)
                        
                        Spacer()
                        
                        Picker("Default Type", selection: $defaultEntryType) {
                            ForEach(EntryType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text("Private Diary")
                                .font(.headline)
                            
                            Text("Your personal diary companion")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("v1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text("Privacy First")
                                .font(.headline)
                            
                            Text("All entries are saved locally and to your Notes app")
                                .font(.caption)
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
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
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

#Preview {
    SettingsView(notificationService: NotificationService())
} 