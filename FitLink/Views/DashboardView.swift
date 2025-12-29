import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var habitTrackerViewModel = HabitTrackerViewModel()
    @StateObject private var activitySummaryViewModel = ActivitySummaryViewModel()
    @StateObject private var router = AppRouter.shared
    @StateObject private var tourCoordinator = OnboardingTourCoordinator.shared
    
    @Namespace private var dashboardNamespace
    @State private var showOnboarding = false
    @State private var navigationPath = NavigationPath()
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Good night"
        }
    }
    
    private var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "☀️"
        case 12..<17: return "🌤️"
        case 17..<22: return "🌅"
        default: return "🌙"
        }
    }
    
    private var displayName: String {
        sessionManager.currentUserDisplayName ?? "there"
    }
    
    private var motivationalQuote: (text: String, author: String) {
        let quotes = [
            ("The only bad workout is the one that didn't happen.", "Unknown"),
            ("Take care of your body. It's the only place you have to live.", "Jim Rohn"),
            ("Fitness is not about being better than someone else. It's about being better than you used to be.", "Khloe Kardashian"),
            ("The body achieves what the mind believes.", "Napoleon Hill"),
            ("Strength does not come from physical capacity. It comes from an indomitable will.", "Mahatma Gandhi"),
            ("Your health is an investment, not an expense.", "Unknown"),
            ("Small steps every day lead to big results.", "Unknown")
        ]
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return quotes[dayOfYear % quotes.count]
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: GlassTokens.Layout.cardSpacing) {
                        heroSection
                            .id("dashboard.hero")
                        quickStatsRow
                            .id("dashboard.quickStats")
                        motivationCard
                        
                        if hasPendingFriendRequests {
                            friendChallengeBanner
                        }
                        
                        sectionHeader("Your Tools")
                        
                        VStack(spacing: 12) {
                            aiWorkoutsCard
                                .id("dashboard.aiWorkouts")
                            aiDietPlannerCard
                                .id("dashboard.aiDiet")
                            habitTrackerCard
                                .id("dashboard.habits")
                        }
                    }
                    .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, GlassTokens.Layout.pageBottomInset + 20)
                }
                .onChange(of: tourCoordinator.scrollToElementID) { _, elementID in
                    guard let elementID else { return }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        scrollProxy.scrollTo(elementID, anchor: .center)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        tourCoordinator.scrollToElementID = nil
                    }
                }
            }
            .background(
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    headerLogo
                }
                ToolbarItem(placement: .topBarTrailing) {
                    profileButton
                }
            }
            .onAppear {
                checkOnboarding()
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
            .navigationDestination(for: AppRouter.AppRoute.self) { route in
                switch route {
                case .dashboard:
                    EmptyView()
                case .dietPlanner, .dietPlan:
                    DietPlannerView()
                        .onAppear { StreakManager.shared.recordAppUsage() }
                case .workouts, .workoutPlan:
                    WorkoutsView()
                        .onAppear { StreakManager.shared.recordAppUsage() }
                case .habitTracker:
                    HabitTrackerView(viewModel: habitTrackerViewModel)
                        .onAppear { StreakManager.shared.recordAppUsage() }
                case .focusSession, .currentFocusSession:
                    HabitTrackerView(viewModel: habitTrackerViewModel)
                        .onAppear { StreakManager.shared.recordAppUsage() }
                case .recipe:
                    DietPlannerView()
                        .onAppear { StreakManager.shared.recordAppUsage() }
                case .activitySummary:
                    ActivitySummaryView(viewModel: activitySummaryViewModel)
                        .onAppear { StreakManager.shared.recordAppUsage() }
                case .friends:
                    FriendsView(userId: sessionManager.currentUserID ?? "")
                        .onAppear { StreakManager.shared.recordAppUsage() }
                case .profile:
                    ProfileMenuView()
                        .onAppear { StreakManager.shared.recordAppUsage() }
                case .settings:
                    SettingsView()
                        .onAppear { StreakManager.shared.recordAppUsage() }
                }
            }
            .onChange(of: router.pendingRoute) { _, newRoute in
                if let route = newRoute {
                    navigationPath.append(route)
                    router.clearPendingRoute()
                }
            }
            .onboardingTourOverlay()
        }
    }
    
    private func checkOnboarding() {
        if !OnboardingManager.shared.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showOnboarding = true
            }
        } else {
            tourCoordinator.startFirstRunTourIfNeeded()
        }
    }
    
    private var headerLogo: some View {
        HStack(spacing: 8) {
            FitLinkIcon.heartRate.image()
                .frame(width: 20, height: 20)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .glassEffect(.regular, in: Circle())
        }
    }
    
    private var profileButton: some View {
        NavigationLink(destination: ProfileMenuView()) {
            ProfileIconView()
        }
        .buttonStyle(.plain)
        .onboardingTarget("dashboard.profile")
    }
    
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(greetingEmoji)
                    .font(.title)
                Text("\(greeting),")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            
            Text(displayName)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Ready to crush your goals today?")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .onboardingTarget("dashboard.hero")
    }
    
    private var quickStatsRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink(destination: CaloriesDetailView(viewModel: activitySummaryViewModel)) {
                    QuickStatCard(
                        icon: .calories,
                        value: "\(formatNumber(activitySummaryViewModel.calories))",
                        label: "cal",
                        gradient: [.orange, .red]
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: StepsDetailView(viewModel: activitySummaryViewModel)) {
                    QuickStatCard(
                        icon: .steps,
                        value: formatNumber(activitySummaryViewModel.steps),
                        label: "steps",
                        gradient: [.blue, .cyan]
                    )
                }
                .buttonStyle(.plain)
                
                QuickStatCard(
                    icon: .streaks,
                    value: "\(streakCount)",
                    label: "streak",
                    gradient: [.yellow, .orange]
                )
            }
            
            HStack(spacing: 12) {
                NavigationLink(destination: SleepDetailView(viewModel: activitySummaryViewModel)) {
                    QuickStatCard(
                        icon: .sleep,
                        value: activitySummaryViewModel.formattedSleepHours,
                        label: "sleep",
                        gradient: [.indigo, .purple]
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: HeartRateDetailView(viewModel: activitySummaryViewModel)) {
                    QuickStatCard(
                        icon: .heartRate,
                        value: "\(activitySummaryViewModel.heartRate)",
                        label: "heart rate",
                        gradient: [.pink, .red]
                    )
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: ExerciseMinutesDetailView(viewModel: activitySummaryViewModel)) {
                    QuickStatCard(
                        icon: .exercise,
                        value: "\(activitySummaryViewModel.exerciseMinutes)",
                        label: "exercise",
                        gradient: [.green, .mint]
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .onboardingTarget("dashboard.quickStats")
    }
    
    private var streakCount: Int {
        StreakManager.shared.getAppStreak()
    }
    
    private var motivationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                FitLinkIcon.quotes.image()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            Text(motivationalQuote.text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Text("— \(motivationalQuote.author)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(GlassTokens.Padding.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
    
    private var hasPendingFriendRequests: Bool {
        false
    }
    
    private var pendingFriendRequestCount: Int {
        0
    }
    
    private var friendChallengeBanner: some View {
        NavigationLink(destination: FriendsView(userId: sessionManager.currentUserID ?? "")) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    FitLinkIcon.friends.image()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Friend Requests")
                        .font(.headline)
                    
                    Text("\(pendingFriendRequestCount) pending request\(pendingFriendRequestCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(GlassTokens.Padding.standard)
            .contentShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
            .glassEffect(.regular.interactive().tint(.orange), in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
            .animation(nil)
        }
        .buttonStyle(.plain)
    }
    
    private var aiWorkoutsCard: some View {
        NavigationLink(destination: WorkoutsView().onAppear { StreakManager.shared.recordAppUsage() }) {
            DashboardNavigationCard(
                icon: .workouts,
                iconColor: .primary,
                title: "AI Workouts",
                subtitle: "Personalized home & gym plans"
            )
        }
        .buttonStyle(.plain)
        .onboardingTarget("dashboard.aiWorkouts")
    }
    
    private var aiDietPlannerCard: some View {
        NavigationLink(destination: DietPlannerView().onAppear { StreakManager.shared.recordAppUsage() }) {
            DashboardNavigationCard(
                icon: .diet,
                iconColor: .primary,
                title: "AI Diet Planner",
                subtitle: "AI-curated weekly meal plans"
            )
        }
        .buttonStyle(.plain)
        .onboardingTarget("dashboard.aiDiet")
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private var habitTrackerCard: some View {
        NavigationLink(destination: HabitTrackerView(viewModel: habitTrackerViewModel).onAppear { StreakManager.shared.recordAppUsage() }) {
            HStack(spacing: 16) {
                FitLinkIcon.habits.image()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.primary)
                    .frame(width: 50, height: 50)
                    .glassEffect(.regular, in: Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Habits")
                        .font(.headline)
                    
                    Text(habitsSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(GlassTokens.Padding.standard)
            .contentShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
            .animation(nil)
        }
        .buttonStyle(.plain)
        .onboardingTarget("dashboard.habits")
    }
    
    private var habitsSummary: String {
        let habits = habitTrackerViewModel.activeHabitsForSelectedDate
        let completed = habits.filter { habitTrackerViewModel.isCompleted(habit: $0, on: Date()) }.count
        let total = habits.count
        
        if total == 0 {
            return "No habits for today"
        }
        
        return "\(completed) of \(total) completed today"
    }
}

struct QuickStatCard: View {
    let icon: FitLinkIcon?
    let sfSymbol: String?
    let value: String
    let label: String
    let gradient: [Color]
    
    init(icon: FitLinkIcon, value: String, label: String, gradient: [Color]) {
        self.icon = icon
        self.sfSymbol = nil
        self.value = value
        self.label = label
        self.gradient = gradient
    }
    
    init(sfSymbol: String, value: String, label: String, gradient: [Color]) {
        self.icon = nil
        self.sfSymbol = sfSymbol
        self.value = value
        self.label = label
        self.gradient = gradient
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let fitLinkIcon = icon {
                    fitLinkIcon.image()
                        .frame(width: 28, height: 28)
                } else if let symbol = sfSymbol {
                    Image(systemName: symbol)
                }
            }
            .font(.title2)
            .foregroundStyle(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .contentShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
        .animation(nil)
    }
}

struct DashboardNavigationCard: View {
    let icon: FitLinkIcon?
    let sfSymbol: String?
    let iconColor: Color
    let title: String
    let subtitle: String
    
    init(icon: FitLinkIcon, iconColor: Color, title: String, subtitle: String) {
        self.icon = icon
        self.sfSymbol = nil
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
    }
    
    init(sfSymbol: String, iconColor: Color, title: String, subtitle: String) {
        self.icon = nil
        self.sfSymbol = sfSymbol
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let fitLinkIcon = icon {
                    fitLinkIcon.image()
                        .frame(width: 32, height: 32)
                } else if let symbol = sfSymbol {
                    Image(systemName: symbol)
                }
            }
            .font(.system(size: 32))
            .foregroundStyle(iconColor)
            .frame(width: 50, height: 50)
            .glassEffect(.regular, in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(GlassTokens.Padding.standard)
        .contentShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
        .animation(nil)
    }
}

#Preview {
    DashboardView()
        .environmentObject(SessionManager.shared)
}
