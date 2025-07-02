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
            VStack(spacing: 16) {
                // Title Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter title...", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.callout)
                }
                .padding(.horizontal)
                
                // Mood Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("How are you feeling? (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(moods, id: \.self) { emoji in
                                Button(emoji) {
                                    mood = mood == emoji ? "" : emoji
                                }
                                .font(.title3)
                                .frame(width: 38, height: 38)
                                .background(mood == emoji ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(mood == emoji ? Color.accentColor.opacity(0.3) : Color(.systemGray4), lineWidth: 0.5)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                
                // Content Editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your thoughts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                            .frame(minHeight: 180)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 0.5)
                            )
                        
                        Group {
                            if #available(iOS 16.0, *) {
                                TextEditor(text: $content)
                                    .scrollContentBackground(.hidden)
                            } else {
                                TextEditor(text: $content)
                            }
                        }
                        .padding(12)
                        .background(Color.clear)
                        .font(.callout)
                        
                        if content.isEmpty {
                            Text("What's on your mind today?")
                                .foregroundColor(.secondary)
                                .font(.callout)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
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
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                        Text("Save to Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(content.isEmpty)
                .opacity(content.isEmpty ? 0.6 : 1.0)
            }
            .navigationTitle("New Text Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline)
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
                .font(.callout)
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