import Foundation
import UIKit
import EventKit

@MainActor
class DiaryService: ObservableObject {
    @Published var entries: [DiaryEntry] = []
    
    private let userDefaults = UserDefaults.standard
    private let entriesKey = "SavedDiaryEntries"
    private let eventStore = EKEventStore()
    
    init() {
        loadEntries()
    }
    
    func saveEntry(_ entry: DiaryEntry) {
        entries.insert(entry, at: 0) // Add to beginning for chronological order
        saveToUserDefaults()
        Task {
            await saveToNotes(entry)
        }
    }
    
    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(entries) {
            userDefaults.set(encoded, forKey: entriesKey)
        }
    }
    
    private func loadEntries() {
        if let data = userDefaults.data(forKey: entriesKey),
           let decoded = try? JSONDecoder().decode([DiaryEntry].self, from: data) {
            entries = decoded
        }
    }
    
    // Save audio file to Documents directory for persistent storage
    func saveAudioFile(_ sourceURL: URL) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "audio_\(Date().timeIntervalSince1970).m4a"
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            print("Error saving audio file: \(error)")
            return nil
        }
    }
    
    // Save video file to Documents directory for persistent storage
    func saveVideoFile(_ sourceURL: URL) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "video_\(Date().timeIntervalSince1970).mov"
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            print("Error saving video file: \(error)")
            return nil
        }
    }
    
    private func saveToNotes(_ entry: DiaryEntry) async {
        // Request access to reminders (Notes uses EKEntityType.reminder)
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            if granted {
                await saveEntryToNotesApp(entry)
            } else {
                print("Notes access denied, falling back to share sheet")
                await MainActor.run {
                    saveToNotesViaShareSheet(entry)
                }
            }
        } catch {
            print("Error requesting Notes access: \(error)")
            await MainActor.run {
                saveToNotesViaShareSheet(entry)
            }
        }
    }
    
    private func saveEntryToNotesApp(_ entry: DiaryEntry) async {
        let noteContent = createNoteContent(entry)
        
        // Create a reminder (which appears in Notes app)
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = entry.title
        reminder.notes = noteContent
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        do {
            try eventStore.save(reminder, commit: true)
            print("Successfully saved to Notes app")
        } catch {
            print("Error saving to Notes: \(error)")
            // Fallback to share sheet
            await MainActor.run {
                saveToNotesViaShareSheet(entry)
            }
        }
    }
    
    private func saveToNotesViaShareSheet(_ entry: DiaryEntry) {
        let noteContent = createNoteContent(entry)
        
        // Use share sheet as fallback
        let activityViewController = UIActivityViewController(
            activityItems: [noteContent],
            applicationActivities: nil
        )
        
        // Get the top view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = topController.view
                popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topController.present(activityViewController, animated: true)
        }
    }
    
    private func createNoteContent(_ entry: DiaryEntry) -> String {
        var noteContent = """
        \(entry.title)
        
        Date: \(entry.formattedDate)
        Type: \(entry.type.rawValue)
        
        \(entry.content)
        """
        
        if let mood = entry.mood {
            noteContent += "\n\nMood: \(mood)"
        }
        
        if entry.type == .audio {
                            noteContent += "\n\n[Audio diary entry recorded in Private Diary app]"
        }
        
        if entry.type == .video {
                            noteContent += "\n\n[Video diary entry recorded in Private Diary app]"
        }
        
        return noteContent
    }
    
    func deleteEntry(_ entry: DiaryEntry) {
        // Delete associated media files
        if let audioURL = entry.audioURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        if let videoURL = entry.videoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
        
        entries.removeAll { $0.id == entry.id }
        saveToUserDefaults()
    }
} 