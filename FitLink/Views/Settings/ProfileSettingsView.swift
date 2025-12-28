import SwiftUI
import Combine

struct ProfileSettingsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var profile: UserProfile?
    @State private var isLoading = true
    @State private var loadingError: String?
    
    @State private var showFitnessEditor = false
    @State private var showDietaryEditor = false
    @State private var showHealthDataStatus = false
    
    @State private var completenessProgress: Double = 0.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: GlassTokens.Layout.cardSpacing) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let profile = profile {
                    completenessCard(profile)
                    healthDataCard(profile)
                    fitnessProfileCard(profile)
                    dietaryProfileCard(profile)
                    patternsCard(profile)
                } else {
                    ContentUnavailableView(
                        "Profile Not Found",
                        systemImage: "person.slash",
                        description: Text(loadingError ?? "Could not load your profile.")
                    )
                    .padding(.top, 40)
                    
                    Button("Retry") {
                        Task { await loadProfile() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
            .padding(.bottom, GlassTokens.Layout.pageBottomInset)
            .padding(.top, 16)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Profile & Personalization")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProfile()
        }
        .sheet(isPresented: $showFitnessEditor) {
            editorPlaceholder(title: "Fitness Profile")
        }
        .sheet(isPresented: $showDietaryEditor) {
            editorPlaceholder(title: "Dietary Profile")
        }
        .sheet(isPresented: $showHealthDataStatus) {
            editorPlaceholder(title: "Health Data Status")
        }
    }
    
    // MARK: - Subviews
    
    private func completenessCard(_ profile: UserProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Profile Completeness")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(profile.profileCompleteness * 100))%")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 12)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * completenessProgress, height: 12)
                            .animation(.spring(response: 1.0, dampingFraction: 0.8), value: completenessProgress)
                    }
                }
                .frame(height: 12)
                
                Text("More data = better personalization")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(GlassTokens.Padding.standard)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    completenessProgress = profile.profileCompleteness
                }
            }
        }
    }
    
    private func healthDataCard(_ profile: UserProfile) -> some View {
        let isConnected = profile.dataSourcesEnabled.contains(.healthKit)
        
        return GlassCard(isInteractive: true) {
            Button(action: { showHealthDataStatus = true }) {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(isConnected ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "heart.text.square.fill")
                            .font(.title2)
                            .foregroundStyle(isConnected ? Color.green : Color.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Health Data")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: isConnected ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.caption)
                            Text(isConnected ? "Connected to HealthKit" : "Not Connected")
                                .font(.subheadline)
                        }
                        .foregroundStyle(isConnected ? .green : .orange)
                        
                        if isConnected {
                            Text("Last synced: 2 min ago")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(GlassTokens.Padding.standard)
            }
        }
    }
    
    private func fitnessProfileCard(_ profile: UserProfile) -> some View {
        GlassCard(isInteractive: true) {
            Button(action: { showFitnessEditor = true }) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("🏋️ Fitness Profile")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow(label: "Level", value: profile.fitnessLevel?.displayName ?? "Not Set")
                        
                        let goals = profile.primaryGoals.map { $0.displayName }.joined(separator: ", ")
                        infoRow(label: "Goals", value: goals.isEmpty ? "Not Set" : goals)
                        
                        let equipment = profile.availableEquipment.map { $0.displayName }.joined(separator: ", ")
                        infoRow(label: "Equipment", value: equipment.isEmpty ? "None" : equipment)
                    }
                    
                    HStack {
                        Spacer()
                        Text("Edit")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding(.top, 4)
                }
                .padding(GlassTokens.Padding.standard)
            }
        }
    }
    
    private func dietaryProfileCard(_ profile: UserProfile) -> some View {
        GlassCard(isInteractive: true) {
            Button(action: { showDietaryEditor = true }) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("🥗 Dietary Profile")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        let restrictions = profile.dietaryRestrictions.map { $0.displayName }.joined(separator: ", ")
                        infoRow(label: "Restrictions", value: restrictions.isEmpty ? "None" : restrictions)
                        
                        let allergies = profile.allergies.joined(separator: ", ")
                        infoRow(label: "Allergies", value: allergies.isEmpty ? "None" : allergies)
                        
                        infoRow(label: "Skill", value: profile.cookingSkillLevel?.displayName ?? "Not Set")
                    }
                    
                    HStack {
                        Spacer()
                        Text("Edit")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding(.top, 4)
                }
                .padding(GlassTokens.Padding.standard)
            }
        }
    }
    
    private func patternsCard(_ profile: UserProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("📈 Your Patterns (Auto-detected)")
                        .font(.headline)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if let wake = profile.detectedWakeTime, let sleep = profile.detectedSleepTime {
                            Text("Wake: ~\(formatTime(wake))")
                            Text("|")
                                .foregroundStyle(.secondary)
                            Text("Sleep: ~\(formatTime(sleep))")
                        } else {
                            Text("Wake/Sleep patterns not yet detected")
                                .italic()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    
                    if !profile.detectedActiveHours.isEmpty {
                        let hours = profile.detectedActiveHours.sorted().map { "\($0):00" }.joined(separator: ", ")
                         Text("Most active hours: \(hours)")
                             .font(.subheadline)
                             .foregroundStyle(.secondary)
                    } else {
                         Text("Activity patterns accumulating...")
                             .font(.subheadline)
                             .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Avg steps: 8,542/day")
                            .font(.subheadline)
                    }
                }
            }
            .padding(GlassTokens.Padding.standard)
        }
    }
    
    // MARK: - Helpers
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
            
            Spacer()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func loadProfile() async {
        guard let userId = sessionManager.currentUserID else {
            loadingError = "Please sign in to view profile."
            isLoading = false
            return
        }
        
        do {
            profile = try await UserProfileService.shared.getOrCreateProfile(for: userId)
            isLoading = false
        } catch {
            AppLogger.shared.error("Error loading profile: \(error.localizedDescription)", category: .user)
            loadingError = error.localizedDescription
            isLoading = false
        }
    }
    
    private func editorPlaceholder(title: String) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)
                Text("Editor Coming Soon")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("This feature is under development.")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let mockProfile = UserProfile(
        userId: "mock_user",
        fitnessLevel: .intermediate,
        primaryGoals: [.buildMuscle, .loseWeight],
        availableEquipment: [.dumbbells, .pullUpBar],
        dietaryRestrictions: [.lowCarb],
        allergies: ["Shellfish", "Tree nuts"],
        cookingSkillLevel: .intermediate,
        detectedWakeTime: Calendar.current.date(bySettingHour: 6, minute: 45, second: 0, of: Date()),
        detectedSleepTime: Calendar.current.date(bySettingHour: 23, minute: 15, second: 0, of: Date()),
        profileCompleteness: 0.72,
        dataSourcesEnabled: [.healthKit]
    )
    
    return NavigationStack {
        ProfileSettingsView()
            .environmentObject(SessionManager.shared)
    }
}
