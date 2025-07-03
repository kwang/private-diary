import SwiftUI

// Simple view to handle local file URLs
struct LocalImageView: View {
    let url: URL
    let isThumbnail: Bool
    @State private var uiImage: UIImage?
    @State private var loadingFailed = false
    
    init(url: URL, isThumbnail: Bool = false) {
        self.url = url
        self.isThumbnail = isThumbnail
    }
    
    var body: some View {
        Group {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            } else if loadingFailed {
                if isThumbnail {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        )
                } else {
                    Color.black
                        .overlay(
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 50))
                                
                                VStack(spacing: 8) {
                                    Text("Photo Not Found")
                                        .foregroundColor(.white)
                                        .font(.title3)
                                        .fontWeight(.medium)
                                    
                                    Text(url.lastPathComponent)
                                        .foregroundColor(.gray)
                                        .font(.callout)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                
                                VStack(spacing: 6) {
                                    Text("This photo file may have been:")
                                        .foregroundColor(.white.opacity(0.8))
                                        .font(.callout)
                                    
                                    VStack(spacing: 4) {
                                        Text("• Moved or deleted from the device")
                                        Text("• Lost during an app reinstall")
                                        Text("• Corrupted or damaged")
                                    }
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                }
                                .padding(.top, 8)
                                

                            }
                            .padding()
                        )
                }
            } else {
                if isThumbnail {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        )
                } else {
                    Color.black
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .foregroundColor(.white)
                                    .font(.system(size: 40))
                                Text("Loading...")
                                    .foregroundColor(.white)
                                    .font(.caption)
                                Text(url.lastPathComponent)
                                    .foregroundColor(.white)
                                    .font(.caption2)
                            }
                        )
                }
            }
        }
        .onAppear {
            Task {
                await loadImage()
            }
        }
        .onChange(of: url) { _ in
            Task {
                await loadImage()
            }
        }
    }
    
    private func loadImage() async {
        do {
            // Check if file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                await MainActor.run {
                    loadingFailed = true
                }
                return
            }
            
            // Load image data
            let data = try Data(contentsOf: url)
            
            // Create UIImage
            guard let image = UIImage(data: data) else {
                await MainActor.run {
                    loadingFailed = true
                }
                return
            }
            
            // Update UI on main thread
            await MainActor.run {
                uiImage = image
                loadingFailed = false
            }
        } catch {
            await MainActor.run {
                loadingFailed = true
            }
        }
    }
}

// Full screen photo viewer
struct PhotoViewerView: View {
    let photoURLs: [URL]
    let selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    
    init(photoURLs: [URL], selectedIndex: Int) {
        self.photoURLs = photoURLs
        self.selectedIndex = selectedIndex
        self._currentIndex = State(initialValue: selectedIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if photoURLs.isEmpty {
                // Handle empty photo list
                VStack(spacing: 20) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundColor(.gray)
                        .font(.system(size: 60))
                    
                    Text("No Photos Available")
                        .foregroundColor(.white)
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("This diary entry doesn't have any photos to display.")
                        .foregroundColor(.gray)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .font(.callout)
                    .padding(.top, 8)
                }
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(photoURLs.indices, id: \.self) { index in
                        LocalImageView(url: photoURLs[index])
                            .aspectRatio(contentMode: .fit)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height > 100 {
                                dismiss()
                            }
                        }
                )
            }
            
            // Simple overlay controls - only show when there are photos
            if !photoURLs.isEmpty {
                VStack {
                    HStack {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .padding()
                        
                        Spacer()
                        
                        if photoURLs.count > 1 {
                            Text("\(currentIndex + 1) of \(photoURLs.count)")
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    if photoURLs.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(0..<photoURLs.count, id: \.self) { index in
                                Circle()
                                    .fill(currentIndex == index ? Color.white : Color.white.opacity(0.5))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
        }
    }
}

#Preview {
    PhotoViewerView(photoURLs: [], selectedIndex: 0)
} 