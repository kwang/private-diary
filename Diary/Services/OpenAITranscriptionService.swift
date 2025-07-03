import Foundation
import AVFoundation

@MainActor
class OpenAITranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionError: String?
    
    private let apiKey: String
    private let apiURL = "https://api.openai.com/v1/audio/transcriptions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Transcribe audio file to text using OpenAI Whisper API
    func transcribeAudio(fileURL: URL) async -> String? {
        guard !apiKey.isEmpty else {
            await MainActor.run {
                self.transcriptionError = "OpenAI API key not configured"
            }
            return nil
        }
        
        await MainActor.run {
            self.isTranscribing = true
            self.transcriptionError = nil
        }
        
        do {
            let audioData = try Data(contentsOf: fileURL)
            let transcription = try await performTranscription(audioData: audioData, fileName: fileURL.lastPathComponent)
            
            await MainActor.run {
                self.isTranscribing = false
            }
            
            return transcription
        } catch {
            await MainActor.run {
                self.isTranscribing = false
                self.transcriptionError = "Transcription failed: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    /// Extract audio from video file and transcribe it
    func transcribeVideo(fileURL: URL) async -> String? {
        guard !apiKey.isEmpty else {
            await MainActor.run {
                self.transcriptionError = "OpenAI API key not configured"
            }
            return nil
        }
        
        await MainActor.run {
            self.isTranscribing = true
            self.transcriptionError = nil
        }
        
        do {
            // Extract audio from video
            let audioURL = try await extractAudioFromVideo(videoURL: fileURL)
            let audioData = try Data(contentsOf: audioURL)
            let transcription = try await performTranscription(audioData: audioData, fileName: "video_audio.m4a")
            
            // Clean up temporary audio file
            try? FileManager.default.removeItem(at: audioURL)
            
            await MainActor.run {
                self.isTranscribing = false
            }
            
            return transcription
        } catch {
            await MainActor.run {
                self.isTranscribing = false
                self.transcriptionError = "Video transcription failed: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    private func performTranscription(audioData: Data, fileName: String) async throws -> String {
        let boundary = UUID().uuidString
        let url = URL(string: apiURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let body = createMultipartBody(audioData: audioData, fileName: fileName, boundary: boundary)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw TranscriptionError.apiError(message)
            } else {
                throw TranscriptionError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw TranscriptionError.invalidResponse
        }
        
        return text
    }
    
    private func createMultipartBody(audioData: Data, fileName: String, boundary: String) -> Data {
        var body = Data()
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add language field (optional - let OpenAI auto-detect)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add response format field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private func extractAudioFromVideo(videoURL: URL) async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent("temp_audio_\(Date().timeIntervalSince1970).m4a")
        
        let asset = AVAsset(url: videoURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.audioExtractionFailed
        }
        
        exportSession.outputURL = audioURL
        exportSession.outputFileType = .m4a
        
        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: audioURL)
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? TranscriptionError.audioExtractionFailed)
                case .cancelled:
                    continuation.resume(throwing: TranscriptionError.audioExtractionFailed)
                default:
                    continuation.resume(throwing: TranscriptionError.audioExtractionFailed)
                }
            }
        }
    }
}

enum TranscriptionError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    case audioExtractionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        case .audioExtractionFailed:
            return "Failed to extract audio from video"
        }
    }
}

// Helper extension for API key management
extension OpenAITranscriptionService {
    static func createWithStoredAPIKey() -> OpenAITranscriptionService {
        let apiKey = UserDefaults.standard.string(forKey: "OpenAI_API_Key") ?? ""
        return OpenAITranscriptionService(apiKey: apiKey)
    }
    
    static func saveAPIKey(_ apiKey: String) {
        UserDefaults.standard.set(apiKey, forKey: "OpenAI_API_Key")
    }
    
    static func getStoredAPIKey() -> String {
        return UserDefaults.standard.string(forKey: "OpenAI_API_Key") ?? ""
    }
} 