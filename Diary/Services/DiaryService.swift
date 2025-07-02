import Foundation
import UIKit

@MainActor
class DiaryService: ObservableObject {
    @Published var entries: [DiaryEntry] = []
    
    private let userDefaults = UserDefaults.standard
    private let entriesKey = "SavedDiaryEntries"
    
    init() {
        loadEntries()
    }
    
    func saveEntry(_ entry: DiaryEntry) {
        entries.insert(entry, at: 0) // Add to beginning for chronological order
        saveToUserDefaults()
        saveToNotes(entry)
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
    
    private func saveToNotes(_ entry: DiaryEntry) {
        var noteContent = """
        \(entry.title)
        
        Date: \(entry.formattedDate)
        Type: \(entry.type.rawValue)
        
        \(entry.content)
        """
        
        if let mood = entry.mood {
            noteContent += "\n\nMood: \(mood)"
        }
        
        // Use share sheet to save to Notes app
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
    
    func deleteEntry(_ entry: DiaryEntry) {
        entries.removeAll { $0.id == entry.id }
        saveToUserDefaults()
    }
} 