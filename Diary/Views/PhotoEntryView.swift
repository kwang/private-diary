import SwiftUI
import PhotosUI
import UIKit

struct PhotoEntryView: View {
    @ObservedObject var diaryService: DiaryService
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var content = ""
    @State private var selectedImages: [UIImage] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var mood = ""
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter diary title", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Content Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextEditor(text: $content)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    
                    // Mood Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mood")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("How are you feeling?", text: $mood)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Photo Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Photos")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Photo picker buttons
                        HStack(spacing: 12) {
                            // Camera button
                            Button {
                                sourceType = .camera
                                showingImagePicker = true
                            } label: {
                                Label("Camera", systemImage: "camera")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            
                            // PhotosPicker for iOS 16+
                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: 5,
                                matching: .images
                            ) {
                                Label("Photo Library", systemImage: "photo.on.rectangle")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }
                            .onChange(of: selectedPhotos) { _ in
                                loadSelectedPhotos()
                            }
                        }
                        
                        // Selected photos display
                        if !selectedImages.isEmpty {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipped()
                                            .cornerRadius(8)
                                        
                                        Button {
                                            selectedImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Color.red)
                                                .clipShape(Circle())
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("New Photo Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(selectedImages.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: sourceType, selectedImages: $selectedImages)
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadSelectedPhotos() {
        guard !selectedPhotos.isEmpty else { return }
        
        Task {
            var newImages: [UIImage] = []
            
            for item in selectedPhotos {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    newImages.append(image)
                }
            }
            
            await MainActor.run {
                selectedImages.append(contentsOf: newImages)
                selectedPhotos.removeAll()
            }
        }
    }
    
    private func saveEntry() {
        var entry = DiaryEntry(
            type: .photo,
            title: title.isEmpty ? "Untitled Entry" : title,
            content: content
        )
        
        // Set additional properties
        entry.mood = mood.isEmpty ? nil : mood
        
        // Save photos and collect URLs
        var photoURLs: [URL] = []
        for image in selectedImages {
            if let url = diaryService.savePhotoFile(image) {
                photoURLs.append(url)
            }
        }
        
        if !photoURLs.isEmpty {
            entry.photoURLs = photoURLs
        }
        
        diaryService.saveEntry(entry)
        dismiss()
    }
}

// MARK: - ImagePicker for camera
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImages.append(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    PhotoEntryView(diaryService: DiaryService())
} 