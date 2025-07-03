import Foundation
import CloudKit
import UIKit

@MainActor
class CloudKitService: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var syncStatus: SyncStatus = .unknown
    @Published var lastSyncDate: Date?
    @Published var errorMessage: String?
    
    private let container = CKContainer.default()
    private let privateDatabase: CKDatabase
    
    enum SyncStatus {
        case unknown
        case syncing
        case synced
        case error
        case noAccount
    }
    
    init() {
        self.privateDatabase = container.privateCloudDatabase
        checkAccountStatus()
    }
    
    // MARK: - Account Management
    
    func checkAccountStatus() {
        isLoading = true
        
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Account check failed: \(error.localizedDescription)"
                    self?.syncStatus = .error
                    return
                }
                
                switch status {
                case .available:
                    self?.isSignedIn = true
                    self?.syncStatus = .synced
                    self?.errorMessage = nil
                case .noAccount:
                    self?.isSignedIn = false
                    self?.syncStatus = .noAccount
                    self?.errorMessage = "No iCloud account found. Please sign in to iCloud in Settings."
                case .restricted:
                    self?.isSignedIn = false
                    self?.syncStatus = .error
                    self?.errorMessage = "iCloud is restricted on this device."
                case .couldNotDetermine:
                    self?.isSignedIn = false
                    self?.syncStatus = .error
                    self?.errorMessage = "Could not determine iCloud account status."
                case .temporarilyUnavailable:
                    self?.isSignedIn = false
                    self?.syncStatus = .error
                    self?.errorMessage = "iCloud is temporarily unavailable."
                @unknown default:
                    self?.isSignedIn = false
                    self?.syncStatus = .error
                    self?.errorMessage = "Unknown iCloud account status."
                }
            }
        }
    }
    
    // MARK: - Sync Operations
    
    func syncDiaryEntries(_ entries: [DiaryEntry]) async -> Bool {
        guard isSignedIn else {
            await MainActor.run {
                syncStatus = .noAccount
                errorMessage = "Not signed in to iCloud"
            }
            return false
        }
        
        await MainActor.run {
            syncStatus = .syncing
            errorMessage = nil
        }
        
        do {
            // First, fetch existing records to check for updates
            let existingRecords = try await fetchAllDiaryRecords()
            
            // Convert entries to CloudKit records
            var recordsToSave: [CKRecord] = []
            
            for entry in entries {
                if let existingRecord = existingRecords.first(where: { $0["entryID"] as? String == entry.id.uuidString }) {
                    // Update existing record
                    updateRecord(existingRecord, with: entry)
                    recordsToSave.append(existingRecord)
                } else {
                    // Create new record
                    let record = createRecord(from: entry)
                    recordsToSave.append(record)
                }
            }
            
            // Save records in batches
            let batchSize = 100
            for i in stride(from: 0, to: recordsToSave.count, by: batchSize) {
                let endIndex = min(i + batchSize, recordsToSave.count)
                let batch = Array(recordsToSave[i..<endIndex])
                
                let operation = CKModifyRecordsOperation(recordsToSave: batch, recordIDsToDelete: nil)
                operation.savePolicy = .changedKeys
                operation.qualityOfService = .userInitiated
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                    privateDatabase.add(operation)
                }
            }
            
            await MainActor.run {
                syncStatus = .synced
                lastSyncDate = Date()
                print("Successfully synced \(entries.count) diary entries to iCloud")
            }
            
            return true
            
        } catch {
            await MainActor.run {
                syncStatus = .error
                errorMessage = "Sync failed: \(error.localizedDescription)"
                print("CloudKit sync error: \(error)")
            }
            return false
        }
    }
    
    func fetchDiaryEntries() async -> [DiaryEntry] {
        guard isSignedIn else {
            await MainActor.run {
                syncStatus = .noAccount
            }
            return []
        }
        
        do {
            let records = try await fetchAllDiaryRecords()
            let entries = records.compactMap { convertRecordToDiaryEntry($0) }
            
            await MainActor.run {
                syncStatus = .synced
                lastSyncDate = Date()
            }
            
            return entries
            
        } catch {
            await MainActor.run {
                syncStatus = .error
                errorMessage = "Failed to fetch entries: \(error.localizedDescription)"
            }
            return []
        }
    }
    
    // MARK: - CloudKit Record Operations
    
    private func fetchAllDiaryRecords() async throws -> [CKRecord] {
        let query = CKQuery(recordType: "DiaryEntry", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let operation: CKQueryOperation
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }
            
            operation.resultsLimit = 100
            operation.qualityOfService = .userInitiated
            
            let (records, nextCursor) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<([CKRecord], CKQueryOperation.Cursor?), Error>) in
                var fetchedRecords: [CKRecord] = []
                
                operation.recordFetchedBlock = { record in
                    fetchedRecords.append(record)
                }
                
                operation.queryCompletionBlock = { cursor, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: (fetchedRecords, cursor))
                    }
                }
                
                privateDatabase.add(operation)
            }
            
            allRecords.append(contentsOf: records)
            cursor = nextCursor
            
        } while cursor != nil
        
        return allRecords
    }
    
    private func createRecord(from entry: DiaryEntry) -> CKRecord {
        let record = CKRecord(recordType: "DiaryEntry")
        updateRecord(record, with: entry)
        return record
    }
    
    private func updateRecord(_ record: CKRecord, with entry: DiaryEntry) {
        record["entryID"] = entry.id.uuidString
        record["title"] = entry.title
        record["content"] = entry.content
        record["type"] = entry.type.rawValue
        record["date"] = entry.date
        record["mood"] = entry.mood
        record["transcription"] = entry.transcription
        
        // Handle file attachments (audio, video, photos)
        if let audioURL = entry.audioURL {
            record["audioAsset"] = CKAsset(fileURL: audioURL)
        }
        
        if let videoURL = entry.videoURL {
            record["videoAsset"] = CKAsset(fileURL: videoURL)
        }
        
        if let photoURLs = entry.photoURLs, !photoURLs.isEmpty {
            let photoAssets = photoURLs.map { CKAsset(fileURL: $0) }
            record["photoAssets"] = photoAssets
        }
    }
    
    private func convertRecordToDiaryEntry(_ record: CKRecord) -> DiaryEntry? {
        guard 
            let entryIDString = record["entryID"] as? String,
            let entryID = UUID(uuidString: entryIDString),
            let title = record["title"] as? String,
            let content = record["content"] as? String,
            let typeString = record["type"] as? String,
            let type = EntryType(rawValue: typeString),
            let date = record["date"] as? Date
        else {
            return nil
        }
        
        var entry = DiaryEntry(
            id: entryID,
            date: date,
            type: type,
            title: title,
            content: content
        )
        
        // Set additional fields
        entry.mood = record["mood"] as? String
        entry.transcription = record["transcription"] as? String
        
        // Handle file attachments
        if let audioAsset = record["audioAsset"] as? CKAsset,
           let audioURL = audioAsset.fileURL {
            entry.audioURL = audioURL
        }
        
        if let videoAsset = record["videoAsset"] as? CKAsset,
           let videoURL = videoAsset.fileURL {
            entry.videoURL = videoURL
        }
        
        if let photoAssets = record["photoAssets"] as? [CKAsset] {
            entry.photoURLs = photoAssets.compactMap { $0.fileURL }
        }
        
        return entry
    }
    
    // MARK: - Manual Sync
    
    func triggerManualSync(entries: [DiaryEntry]) async {
        await MainActor.run {
            syncStatus = .syncing
        }
        
        let success = await syncDiaryEntries(entries)
        if success {
            print("Manual sync completed successfully")
        }
    }
    
    // MARK: - Settings Actions
    
    func openCloudSettings() {
        if let settingsUrl = URL(string: "App-Prefs:APPLE_ACCOUNT&path=ICLOUD_SERVICE") {
            UIApplication.shared.open(settingsUrl)
        } else if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
} 