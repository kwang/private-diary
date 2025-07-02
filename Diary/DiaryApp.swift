//
//  DiaryApp.swift
//  Diary
//
//  Created by Kate Wang on 7/2/25.
//

import SwiftUI
import UserNotifications

@main
struct DiaryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle deep links from notifications
                    if url.scheme == "privatediary" {
                        // Open appropriate entry view based on URL
                        print("Opened from notification: \(url)")
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.list, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let action = userInfo["action"] as? String, action == "openDiary" {
            // Post notification to open diary
            NotificationCenter.default.post(name: .openDiaryFromNotification, object: nil)
        }
        
        completionHandler()
    }
}

extension Notification.Name {
    static let openDiaryFromNotification = Notification.Name("openDiaryFromNotification")
}
