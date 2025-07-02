import Foundation
import UserNotifications

@MainActor
class NotificationService: ObservableObject {
    @Published var isAuthorized = false
    @Published var reminderTime = Date()
    @Published var reminderEnabled = false
    
    private let userDefaults = UserDefaults.standard
    private let reminderTimeKey = "ReminderTime"
    private let reminderEnabledKey = "ReminderEnabled"
    
    init() {
        loadSettings()
        checkAuthorizationStatus()
    }
    
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            
            if granted && reminderEnabled {
                await scheduleReminder()
            }
        } catch {
            print("Error requesting notification permission: \(error)")
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func scheduleReminder() async {
        guard isAuthorized && reminderEnabled else { return }
        
        // Remove existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = "Time to reflect 📝"
        content.body = "How was your day? Take a moment to record your thoughts."
        content.sound = UNNotificationSound.default
        content.userInfo = ["action": "openDiary"]
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Daily reminder scheduled for \(reminderTime)")
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
    
    func toggleReminder() {
        reminderEnabled.toggle()
        saveSettings()
        
        if reminderEnabled {
            Task {
                await scheduleReminder()
            }
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    
    func updateReminderTime(_ newTime: Date) {
        reminderTime = newTime
        saveSettings()
        
        if reminderEnabled {
            Task {
                await scheduleReminder()
            }
        }
    }
    
    func saveSettings() {
        userDefaults.set(reminderTime, forKey: reminderTimeKey)
        userDefaults.set(reminderEnabled, forKey: reminderEnabledKey)
    }
    
    private func loadSettings() {
        if let savedTime = userDefaults.object(forKey: reminderTimeKey) as? Date {
            reminderTime = savedTime
        } else {
            // Default to 8 PM
            let calendar = Calendar.current
            let now = Date()
            reminderTime = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
        }
        
        reminderEnabled = userDefaults.bool(forKey: reminderEnabledKey)
    }
} 