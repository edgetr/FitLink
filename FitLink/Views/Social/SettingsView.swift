import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) var colorScheme
    
    // Appearance
    @AppStorage("app_preferred_color_scheme") private var preferredColorScheme: Int = 2 // 0: System, 1: Light, 2: Dark
    
    // Notifications
    @AppStorage("notifications_enabled") private var notificationsEnabled = true
    @AppStorage("friend_request_notifications") private var friendRequestNotifications = true
    @AppStorage("activity_reminders") private var activityReminders = true
    @AppStorage("weekly_reports") private var weeklyReports = true
    
    // Privacy
    @AppStorage("share_activity") private var shareActivity = true
    @AppStorage("appear_in_search") private var appearInSearch = true
    
    // Alert States
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showExportDataAlert = false
    
    // Namespace for animations
    @Namespace private var themePickerNamespace
    
    // App Version
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
    
var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
                            .font(.body)
                        
                        LiquidGlassSegmentedPicker(
                            selection: $preferredColorScheme,
                            options: [
                                (0, "System"),
                                (1, "Light"),
                                (2, "Dark")
                            ],
                            namespace: themePickerNamespace
                        )
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                }
                
                List {
                    Section {
                        Toggle("Push Notifications", isOn: $notificationsEnabled)
                        Toggle("Friend Request Alerts", isOn: $friendRequestNotifications)
                        Toggle("Activity Reminders", isOn: $activityReminders)
                        Toggle("Weekly Reports", isOn: $weeklyReports)
                    } header: {
                        Text("Notifications")
                    }
                    
                    Section {
                        Toggle("Share Activity with Friends", isOn: $shareActivity)
                        Toggle("Appear in Search", isOn: $appearInSearch)
                    } header: {
                        Text("Privacy")
                    }
                    
                    Section {
                        Button(action: { showSignOutAlert = true }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.red)
                        }
                        
                        Button(action: { showDeleteAccountAlert = true }) {
                            Label("Delete Account", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                        
                        Button(action: { showExportDataAlert = true }) {
                            Label("Export My Data", systemImage: "square.and.arrow.up")
                                .foregroundStyle(.primary)
                        }
                    } header: {
                        Text("Account")
                    }
                    
                    Section {
                        linkRow(title: "Privacy Policy", url: "https://fitlink.app/privacy")
                        linkRow(title: "Terms of Service", url: "https://fitlink.app/terms")
                        
                        Button(action: {
                            if let url = URL(string: "mailto:support@fitlink.app") {
                                openURL(url)
                            }
                        }) {
                            Label("Contact Support", systemImage: "envelope")
                                .foregroundStyle(.primary)
                        }
                        
                        Button(action: {
                            if let url = URL(string: "https://apps.apple.com/app/id123456789") {
                                openURL(url)
                            }
                        }) {
                            Label("Rate on App Store", systemImage: "star")
                                .foregroundStyle(.primary)
                        }
                        
                        HStack {
                            Text("App Version")
                            Spacer()
                            Text(appVersion)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("About")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDisabled(true)
                .frame(height: 650)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(selectedColorScheme)
        // Sign Out Alert
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                try? sessionManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        // Delete Account Alert
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Mock deletion action
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        // Export Data Alert
        .alert("Coming Soon", isPresented: $showExportDataAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Data export functionality will be available in a future update.")
        }
    }
    
    private var selectedColorScheme: ColorScheme? {
        switch preferredColorScheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
    
    private func linkRow(title: String, url: String) -> some View {
        Button(action: {
            if let linkUrl = URL(string: url) {
                openURL(linkUrl)
            }
        }) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SessionManager.shared)
    }
}
