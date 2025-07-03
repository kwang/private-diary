import SwiftUI
import PhotosUI
import UIKit

@available(iOS 15.0, *)
struct PhotoEntryView: View {
    @ObservedObject var diaryService: DiaryService
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var content = ""
    @State private var selectedImages: [UIImage] = []
    @State private var selectedPhotos: [Any] = [] // Using Any for iOS 15 compatibility
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
                    // Title Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Enter title...", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Photo Selection Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Photos")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                sourceType = .camera
                                showingCamera = true
                            }) {
                                Label("Camera", systemImage: "camera")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            
                            if #available(iOS 16.0, *) {
                                PhotosPicker(
                                    selection: Binding(
                                        get: { selectedPhotos as? [PhotosPickerItem] ?? [] },
                                        set: { 
                                            selectedPhotos = $0
                                            loadSelectedPhotos()
                                        }
                                    ),
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
                            } else {
                                Button(action: {
                                    sourceType = .photoLibrary
                                    showingImagePicker = true
                                }) {
                                    Label("Photo Library", systemImage: "photo.on.rectangle")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.green)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        
                        // Selected Photos Grid
                        if !selectedImages.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipped()
                                            .cornerRadius(8)
                                        
                                        Button(action: {
                                            selectedImages.remove(at: index)
                                        }) {
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
                    
                    // Content Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Caption")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextEditor(text: $content)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Mood Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mood (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("How are you feeling?", text: $mood)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Photo Entry")
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
        .sheet(isPresented: $showingCamera) {
            ImagePicker(sourceType: sourceType) { image in
                selectedImages.append(image)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: sourceType) { image in
                selectedImages.append(image)
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            title = "Photo Entry - \(DateFormatter.entryFormatter.string(from: Date()))"
        }
    }
    
    @available(iOS 16.0, *)
    private func loadSelectedPhotos() {
        guard let photosPickerItems = selectedPhotos as? [PhotosPickerItem] else { return }
        
        Task {
            var newImages: [UIImage] = []
            
            for photo in photosPickerItems {
                if let data = try? await photo.loadTransferable(type: Data.self),
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
        guard !selectedImages.isEmpty else { return }
        
        var entry = DiaryEntry(type: .photo, title: title.isEmpty ? nil : title, content: content)
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
            diaryService.saveEntry(entry)
            dismiss()
        } else {
            alertMessage = "Failed to save photos. Please try again."
            showingAlert = true
        }
    }
}

// Image Picker for Camera and Photo Library
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
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
                parent.onImagePicked(image)
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