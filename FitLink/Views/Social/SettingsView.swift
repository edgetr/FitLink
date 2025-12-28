import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = SettingsViewModel()
    
    @AppStorage("app_preferred_color_scheme") private var preferredColorScheme: Int = 2
    
    // Notifications
    @AppStorage("notifications_enabled") private var notificationsEnabled = true
    @AppStorage("friend_request_notifications") private var friendRequestNotifications = true
    @AppStorage("activity_reminders") private var activityReminders = true
    @AppStorage("weekly_reports") private var weeklyReports = true
    
    // Privacy
    @AppStorage("share_activity") private var shareActivity = true
    @AppStorage("appear_in_search") private var appearInSearch = true
    
    // Health Data Storage
    @ObservedObject private var healthStorageSettings = HealthDataStorageSettings.shared
    
    // Alert States
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showExportDataAlert = false
    @State private var showDeleteHealthDataAlert = false
    @State private var showDeleteAccountErrorAlert = false
    
    // Namespace for animations
    @Namespace private var themePickerNamespace
    
    // App Version
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
    
var body: some View {
        List {
            // MARK: - Appearance Section
            Section {
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
            } header: {
                Text("Appearance")
            }
            
            // MARK: - Notifications Section
            Section {
                Toggle("Push Notifications", isOn: $notificationsEnabled)
                Toggle("Friend Request Alerts", isOn: $friendRequestNotifications)
                Toggle("Activity Reminders", isOn: $activityReminders)
                Toggle("Weekly Reports", isOn: $weeklyReports)
            } header: {
                Text("Notifications")
            }
            
            // MARK: - Privacy Section
            Section {
                Toggle("Share Activity with Friends", isOn: $shareActivity)
                Toggle("Appear in Search", isOn: $appearInSearch)
                
                Toggle("Sync Health Data to Cloud", isOn: Binding(
                    get: { healthStorageSettings.isCloudSyncEnabled },
                    set: { enabled in
                        if enabled {
                            healthStorageSettings.enableCloudSync()
                        } else {
                            healthStorageSettings.disableCloudSync()
                        }
                    }
                ))
                
                if healthStorageSettings.hasCloudData {
                    Button(action: { showDeleteHealthDataAlert = true }) {
                        Label("Delete Cloud Health Data", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text(healthStorageSettings.policy.description)
            }
            
            // MARK: - Personalization Section
            Section {
                NavigationLink(destination: MemoriesView()) {
                    HStack {
                        Label("Memories", systemImage: "brain.head.profile")
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("\(viewModel.memoriesCount)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink(destination: HealthDataStatusView()) {
                    Label("Health Data", systemImage: "heart.text.square")
                }
                
                NavigationLink(destination: ProfileSettingsView()) {
                    Label("Profile & Personalization", systemImage: "person.crop.circle.badge.checkmark")
                }
                
                Button {
                    OnboardingManager.shared.resetTour("first_run")
                    OnboardingTourCoordinator.shared.startTour(.firstRunTour)
                } label: {
                    Label("Restart App Tour", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("Personalization")
            } footer: {
                Text("FitLink learns your preferences to create better workout and meal plans.")
            }
            
            // MARK: - Account Section
            Section {
                Button(action: { showSignOutAlert = true }) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
                
                if FeatureFlags.isAccountDeletionEnabled {
                    Button(action: { showDeleteAccountAlert = true }) {
                        HStack {
                            Label("Delete Account", systemImage: "trash")
                            if viewModel.isDeletingAccount {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .foregroundStyle(.red)
                    }
                    .disabled(viewModel.isDeletingAccount)
                }
                
                if FeatureFlags.isDataExportEnabled {
                    Button(action: { showExportDataAlert = true }) {
                        Label("Export My Data", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.primary)
                    }
                }
            } header: {
                Text("Account")
            }
            
            // MARK: - About Section
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
        .task {
            await viewModel.loadMemoriesCount()
        }
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
                Task {
                    let success = await viewModel.deleteAccount()
                    if !success {
                        showDeleteAccountErrorAlert = true
                    }
                }
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .alert("Deletion Failed", isPresented: $showDeleteAccountErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.deleteAccountError ?? "An unexpected error occurred. Please try again.")
        }
        // Export Data Alert
        .alert("Coming Soon", isPresented: $showExportDataAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Data export functionality will be available in a future update.")
        }
        .alert("Delete Cloud Health Data", isPresented: $showDeleteHealthDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteCloudHealthData()
                }
            }
        } message: {
            Text("This will permanently delete your health data from the cloud. Data in Apple Health will not be affected.")
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
    
    private func deleteCloudHealthData() async {
        guard let userId = sessionManager.currentUserID else { return }
        do {
            try await HealthMetricsService.shared.deleteMetricsStore(for: userId)
            healthStorageSettings.recordCloudDataDeleted()
        } catch {
            print("[SettingsView] Failed to delete cloud health data: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SessionManager.shared)
    }
}
