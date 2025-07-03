import Foundation
import UIKit
import SwiftUI

@MainActor
class DiaryService: ObservableObject {
    @Published var entries: [DiaryEntry] = []
    @Published var iCloudSyncEnabled = false
    
    private let userDefaults = UserDefaults.standard
    private let entriesKey = "SavedDiaryEntries"
    private let iCloudSyncKey = "iCloudSyncEnabled"
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    #if targetEnvironment(simulator)
    @Published var cloudKitService = CloudKitService()
    #endif
    
    @AppStorage("enableAutoSync") var enableAutoSync: Bool = true
    @AppStorage("lastSyncTime") private var lastSyncTime: Double = 0
    
    init() {
        loadSettings()
        loadEntries()
        

        
        // Auto-sync if enabled and signed in (simulator only)
        #if targetEnvironment(simulator)
        Task {
            if iCloudSyncEnabled && cloudKitService.isSignedIn {
                await syncWithiCloud()
            }
        }
        #endif
    }
    

    
    func saveEntry(_ entry: DiaryEntry) {
        entries.insert(entry, at: 0) // Add to beginning for chronological order
        saveToUserDefaults()
        
        Task {
            await saveToLocalFile(entry)
            
            // Auto-sync to iCloud if enabled (simulator only)
            #if targetEnvironment(simulator)
            if iCloudSyncEnabled && cloudKitService.isSignedIn {
                await syncWithiCloud()
            }
            #endif
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
            
            // Recover broken file paths after loading entries
            recoverBrokenFilePaths()
        }
    }
    
    // Recover broken file paths that may have been invalidated by app reinstalls
    private func recoverBrokenFilePaths() {
        var needsUpdate = false
        
        for i in 0..<entries.count {
            var entry = entries[i]
            
            // Check and recover audio files
            if let audioURL = entry.audioURL, !FileManager.default.fileExists(atPath: audioURL.path) {
                if let recoveredURL = recoverAudioFile(from: audioURL) {
                    entry.audioURL = recoveredURL
                    entries[i] = entry
                    needsUpdate = true
                    print("Recovered audio file: \(recoveredURL.lastPathComponent)")
                }
            }
            
            // Check and recover video files
            if let videoURL = entry.videoURL, !FileManager.default.fileExists(atPath: videoURL.path) {
                if let recoveredURL = recoverVideoFile(from: videoURL) {
                    entry.videoURL = recoveredURL
                    entries[i] = entry
                    needsUpdate = true
                    print("Recovered video file: \(recoveredURL.lastPathComponent)")
                }
            }
            
            // Check and recover photo files
            if let photoURLs = entry.photoURLs {
                var recoveredPhotoURLs: [URL] = []
                var photosRecovered = false
                
                for photoURL in photoURLs {
                    if FileManager.default.fileExists(atPath: photoURL.path) {
                        recoveredPhotoURLs.append(photoURL)
                    } else {
                        // Try to recover photo
                        let fileName = photoURL.lastPathComponent
                        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let expectedURL = documentsPath.appendingPathComponent(fileName)
                        
                        if FileManager.default.fileExists(atPath: expectedURL.path) {
                            recoveredPhotoURLs.append(expectedURL)
                            photosRecovered = true
                            print("Recovered photo file: \(fileName)")
                        }
                    }
                }
                
                if photosRecovered {
                    entry.photoURLs = recoveredPhotoURLs.isEmpty ? nil : recoveredPhotoURLs
                    entries[i] = entry
                    needsUpdate = true
                }
            }
        }
        
        // Save updated entries if any paths were recovered
        if needsUpdate {
            saveToUserDefaults()
            print("Updated \(entries.count) diary entries with recovered file paths")
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
    
    // Recover missing audio files by searching for them in the Documents directory
    func recoverAudioFile(from storedURL: URL) -> URL? {
        let fileName = storedURL.lastPathComponent
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let expectedURL = documentsPath.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: expectedURL.path) {
            return expectedURL
        }
        
        // Try to find the file in the Documents directory
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            for file in contents {
                if file.lastPathComponent == fileName {
                    return file
                }
            }
        } catch {
            print("Error searching for audio file: \(error)")
        }
        
        return nil
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
    
    // Recover missing video files by searching for them in the Documents directory
    func recoverVideoFile(from storedURL: URL) -> URL? {
        let fileName = storedURL.lastPathComponent
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let expectedURL = documentsPath.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: expectedURL.path) {
            return expectedURL
        }
        
        // Try to find the file in the Documents directory
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            for file in contents {
                if file.lastPathComponent == fileName {
                    return file
                }
            }
        } catch {
            print("Error searching for video file: \(error)")
        }
        
        return nil
    }
    
    // Save photo file to Documents directory for persistent storage
    func savePhotoFile(_ image: UIImage) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "photo_\(Date().timeIntervalSince1970).jpg"
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                try imageData.write(to: destinationURL)
                return destinationURL
            }
        } catch {
            print("Error saving photo file: \(error)")
        }
        return nil
    }
    
    private func saveToLocalFile(_ entry: DiaryEntry) async {
        let fileName = "diary_entry_\(entry.id.uuidString).txt"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        let content = createEntryContent(entry)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved diary entry to local file: \(fileName)")
        } catch {
            print("Error saving diary entry to local file: \(error)")
        }
    }
    
    private func createEntryContent(_ entry: DiaryEntry) -> String {
        var content = """
        \(entry.title)
        
        Date: \(entry.formattedDate)
        Type: \(entry.type.rawValue)
        Entry ID: \(entry.id.uuidString)
        
        \(entry.content)
        """
        
        if let mood = entry.mood {
            content += "\n\nMood: \(mood)"
        }
        
        if let transcription = entry.transcription, !transcription.isEmpty {
            content += "\n\nTranscription:\n\(transcription)"
        }
        
        // Add file references
        if let audioURL = entry.audioURL {
            content += "\n\nAudio File: \(audioURL.lastPathComponent)"
        }
        
        if let videoURL = entry.videoURL {
            content += "\n\nVideo File: \(videoURL.lastPathComponent)"
        }
        
        if let photoURLs = entry.photoURLs {
            content += "\n\nPhoto Files:"
            for photoURL in photoURLs {
                content += "\n- \(photoURL.lastPathComponent)"
            }
        }
        
        content += "\n\n---\nSaved from Private Diary App\n\(Date().formatted(date: .complete, time: .complete))"
        
        return content
    }
    
    func deleteEntry(_ entry: DiaryEntry) {
        // Delete associated media files
        if let audioURL = entry.audioURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        if let videoURL = entry.videoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
        if let photoURLs = entry.photoURLs {
            for photoURL in photoURLs {
                try? FileManager.default.removeItem(at: photoURL)
            }
        }
        
        // Delete associated text file
        let fileName = "diary_entry_\(entry.id.uuidString).txt"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
        
        entries.removeAll { $0.id == entry.id }
        saveToUserDefaults()
    }
    
    // Manual recovery function that can be triggered by users
    func recoverAllMissingFiles() {
        recoverBrokenFilePaths()
    }
    
    // Get statistics about missing files
    var missingFileStats: (audio: Int, video: Int, photos: Int) {
        var audioMissing = 0
        var videoMissing = 0
        var photosMissing = 0
        
        for entry in entries {
            if let audioURL = entry.audioURL, !FileManager.default.fileExists(atPath: audioURL.path) {
                audioMissing += 1
            }
            if let videoURL = entry.videoURL, !FileManager.default.fileExists(atPath: videoURL.path) {
                videoMissing += 1
            }
            if let photoURLs = entry.photoURLs {
                for photoURL in photoURLs {
                    if !FileManager.default.fileExists(atPath: photoURL.path) {
                        photosMissing += 1
                    }
                }
            }
        }
        
        return (audioMissing, videoMissing, photosMissing)
    }
    
    // MARK: - iCloud Sync Management
    
    private func loadSettings() {
        iCloudSyncEnabled = userDefaults.bool(forKey: iCloudSyncKey)
    }
    
    func setiCloudSyncEnabled(_ enabled: Bool) {
        iCloudSyncEnabled = enabled
        userDefaults.set(enabled, forKey: iCloudSyncKey)
        
        #if targetEnvironment(simulator)
        if enabled && cloudKitService.isSignedIn {
            Task {
                await syncWithiCloud()
            }
        }
        #endif
    }
    
    func syncWithiCloud() async {
        #if targetEnvironment(simulator)
        guard iCloudSyncEnabled && cloudKitService.isSignedIn else { return }
        
        let success = await cloudKitService.syncDiaryEntries(entries)
        if success {
            await MainActor.run {
                lastSyncTime = Date().timeIntervalSince1970
            }
        }
        #else
        // CloudKit not available on device - do nothing
        print("CloudKit sync not available on device builds")
        #endif
    }
    
    func downloadFromiCloud() async {
        #if targetEnvironment(simulator)
        guard iCloudSyncEnabled && cloudKitService.isSignedIn else { return }
        
        let cloudEntries = await cloudKitService.fetchDiaryEntries()
        
        await MainActor.run {
            // Merge cloud entries with local entries
            var mergedEntries = entries
            
            for cloudEntry in cloudEntries {
                if !mergedEntries.contains(where: { $0.id == cloudEntry.id }) {
                    mergedEntries.append(cloudEntry)
                }
            }
            
            // Sort by date
            mergedEntries.sort { $0.date > $1.date }
            entries = mergedEntries
            
            saveToUserDefaults()
            lastSyncTime = Date().timeIntervalSince1970
        }
        #else
        // CloudKit not available on device - do nothing
        print("CloudKit download not available on device builds")
        #endif
    }
    
    func triggerManualSync() async {
        #if targetEnvironment(simulator)
        await cloudKitService.triggerManualSync(entries: entries)
        await MainActor.run {
            if let syncDate = cloudKitService.lastSyncDate {
                lastSyncTime = syncDate.timeIntervalSince1970
            }
        }
        #else
        // CloudKit not available on device - do nothing
        print("CloudKit manual sync not available on device builds")
        #endif
    }
    
    // Check if iCloud is available and user is signed in
    var canUseiCloud: Bool {
        #if targetEnvironment(simulator)
        return cloudKitService.isSignedIn
        #else
        return false
        #endif
    }
    
    var iCloudStatus: String {
        #if targetEnvironment(simulator)
        if cloudKitService.isLoading {
            return "Checking iCloud status..."
        } else if cloudKitService.isSignedIn {
            return "iCloud Available"
        } else {
            return cloudKitService.errorMessage ?? "iCloud not available"
        }
        #else
        return "iCloud not available (device build)"
        #endif
    }
    
    // MARK: - Local Files Management
    
    func listSavedDiaryFiles() -> [String] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "txt" && $0.lastPathComponent.starts(with: "diary_entry_") }
                       .map { $0.lastPathComponent }
                       .sorted()
        } catch {
            print("Error listing diary files: \(error)")
            return []
        }
    }
    
    func getDiaryFilePath(for entryID: UUID) -> URL {
        let fileName = "diary_entry_\(entryID.uuidString).txt"
        return documentsDirectory.appendingPathComponent(fileName)
    }
    

} 
