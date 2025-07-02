# Daylink - iOS Diary App

A beautiful, privacy-first diary application for iOS built with SwiftUI, following Apple's Human Interface Guidelines.

![iOS](https://img.shields.io/badge/iOS-18.5+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0+-green.svg)
![Xcode](https://img.shields.io/badge/Xcode-16.0+-blue.svg)

## ✨ Features

### 📝 **Multi-Format Diary Entries**
- **Text Entries**: Rich text editor with mood selection and auto-generated titles
- **Audio Entries**: High-quality audio recording with playback capabilities
- **Video Entries**: Video recording (camera on device, photo library on simulator)

### 🔔 **Smart Reminders**
- Customizable daily notification reminders
- Deep linking back to the app for quick entry creation
- Notification permission handling with user-friendly prompts

### 📱 **Notes App Integration**
- Automatic backup of all entries to the system Notes app
- Privacy-first approach - all data stays on your device
- Share sheet integration for seamless saving

### ⚙️ **Settings & Customization**
- Configure reminder times and preferences
- Toggle reminder notifications on/off
- Clean, intuitive settings interface

## 🏗 Architecture

### **MVVM Pattern with SwiftUI**
- `Models/`: Core data structures (`DiaryEntry`, `EntryType`)
- `Views/`: SwiftUI views for each feature area
- `Services/`: Business logic (`DiaryService`, `NotificationService`)

### **Key Technologies**
- **SwiftUI**: Modern declarative UI framework
- **AVFoundation**: Audio/video recording and playback
- **UserNotifications**: Local notification scheduling
- **UIKit Integration**: Camera and photo picker functionality

## 📂 Project Structure

```
Diary/
├── Models/
│   └── DiaryEntry.swift          # Core data model
├── Services/
│   ├── DiaryService.swift        # Entry management
│   └── NotificationService.swift # Reminder notifications
├── Views/
│   ├── HomeView.swift           # Main dashboard
│   ├── TextEntryView.swift      # Text diary creation
│   ├── AudioEntryView.swift     # Audio recording
│   ├── VideoEntryView.swift     # Video recording
│   └── SettingsView.swift       # App preferences
├── Assets.xcassets/             # App icons and colors
├── ContentView.swift            # Root view
└── DiaryApp.swift              # App entry point
```

## 🚀 Getting Started

### **Prerequisites**
- macOS 14.0+ (Sonoma)
- Xcode 16.0+
- iOS 18.5+ Simulator or Device

### **Installation**

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Diary
   ```

2. **Open in Xcode**
   ```bash
   open Diary.xcodeproj
   ```

3. **Build and Run**
   - Select your target device/simulator
   - Press `Cmd + R` to build and run

## 🌐 Remote Repository Setup (Optional)

If you want to push this to a remote repository:

### **Option 1: GitHub**
```bash
# Create a new repository on GitHub, then:
git remote add origin https://github.com/kawang/daylink-ios.git
git branch -M main
git push -u origin main
```

### **Option 2: GitLab**
```bash
git remote add origin https://gitlab.com/kawang/daylink-ios.git
git push -u origin main
```

### **Option 3: Keep Local Only**
Your repository is perfectly functional as a local Git repo for version control and backup purposes!

## 🧪 Testing

### **Simulator vs Device Differences**
- **Text & Audio**: Work identically on both
- **Video Recording**: 
  - ✅ **Device**: Uses camera for recording
  - ✅ **Simulator**: Uses photo library for selection

### **Permissions Testing**
The app handles the following permissions gracefully:
- Microphone access (for audio recording)
- Camera access (for video recording)
- Photo library access (simulator video fallback)
- Notification permissions (for reminders)

## 🔐 Privacy & Security

- **Local Storage**: All diary entries stored locally using UserDefaults
- **No Cloud Sync**: Complete privacy - data never leaves your device
- **Permission Transparency**: Clear explanations for all permission requests
- **Notes Integration**: Optional backup to system Notes app

## 📱 Supported Platforms

- **iPhone**: iOS 18.5+
- **iPad**: iPadOS 18.5+
- **Simulator**: Full feature compatibility

## 🎨 Design Philosophy

Following Apple's Human Interface Guidelines:
- **Intuitive Navigation**: Clear, purposeful interface design
- **Accessibility**: VoiceOver and Dynamic Type support
- **Visual Consistency**: System colors and typography
- **Responsive Layout**: Adapts to different screen sizes

## 🔄 Version History

### v1.0.0 (Current)
- Initial release with core diary functionality
- Text, audio, and video entry support
- Daily reminder notifications
- Notes app integration
- Privacy-focused design

## 🛠 Development Notes

### **Build Configuration**
- Privacy usage descriptions automatically included via `INFOPLIST_KEY_*` settings
- Automatic Info.plist generation enabled
- Swift Package Manager ready

### **Known Considerations**
- Video recording requires physical device camera
- Simulator uses photo library as fallback for video
- Notification permissions require user acceptance

## 📄 License

This project is developed for educational and personal use.

## 🔄 Future Development

When you make changes to your app:
```bash
git add .
git commit -m "Your commit message"
git push  # (if you set up a remote repository)
```

## 🤝 Contributing

This is a personal diary app project. Feel free to fork and adapt for your own needs!

---

**Built with ❤️ using SwiftUI and following Apple's best practices** 