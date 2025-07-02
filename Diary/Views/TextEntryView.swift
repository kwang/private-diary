import SwiftUI

struct TextEntryView: View {
    @ObservedObject var diaryService: DiaryService
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var content = ""
    @State private var mood = ""
    @State private var showingSaveAlert = false
    
    private let moods = ["😊", "😔", "😤", "😌", "🤔", "😴", "🥳", "😰", "❤️", "🙄"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Title Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.headline)
                    
                    TextField("Enter title...", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Mood Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("How are you feeling? (Optional)")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(moods, id: \.self) { emoji in
                                Button(emoji) {
                                    mood = mood == emoji ? "" : emoji
                                }
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(mood == emoji ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Content Editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your thoughts")
                        .font(.headline)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(minHeight: 200)
                        
                        TextEditor(text: $content)
                            .padding(12)
                            .background(Color.clear)
                            .scrollContentBackground(.hidden)
                            .font(.body)
                        
                        if content.isEmpty {
                            Text("What's on your mind today?")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Save Button
                Button {
                    saveEntry()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save to Notes")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(content.isEmpty)
            }
            .navigationTitle("New Text Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Auto-generate title with current date/time
            title = "Diary - \(DateFormatter.entryFormatter.string(from: Date()))"
        }
        .alert("Entry Saved!", isPresented: $showingSaveAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your diary entry has been saved and will be shared to Notes.")
        }
    }
    
    private func saveEntry() {
        var entry = DiaryEntry(type: .text, title: title, content: content)
        entry.mood = mood.isEmpty ? nil : mood
        
        diaryService.saveEntry(entry)
        showingSaveAlert = true
    }
}

#Preview {
    TextEntryView(diaryService: DiaryService())
} 