import Foundation
import SwiftUI

enum EntryType: String, CaseIterable, Codable {
    case text = "✍️ Text"
    case audio = "🎧 Audio"
    case video = "🎥 Video"
    case photo = "📷 Photo"
    
    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .audio: return "mic.fill"
        case .video: return "video.fill"
        case .photo: return "camera.fill"
        }
    }
}

struct DiaryEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    var title: String
    let type: EntryType
    var content: String
    var audioURL: URL?
    var videoURL: URL?
    var photoURLs: [URL]?
    var mood: String?
    var transcription: String?
    
    init(type: EntryType, title: String? = nil, content: String = "") {
        self.id = UUID()
        self.date = Date()
        self.type = type
        self.title = title ?? "Diary - \(DateFormatter.entryFormatter.string(from: Date()))"
        self.content = content
    }
    
    // Initialize with specific ID and date for CloudKit sync
    init(id: UUID, date: Date, type: EntryType, title: String, content: String) {
        self.id = id
        self.date = date
        self.type = type
        self.title = title
        self.content = content
    }
    
    var formattedDate: String {
        DateFormatter.displayFormatter.string(from: date)
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension DateFormatter {
    static let entryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
} 