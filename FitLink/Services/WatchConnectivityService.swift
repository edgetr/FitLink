import Foundation
import WatchConnectivity
import Combine

#if os(iOS)

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {
    
    static let shared = WatchConnectivityService()
    
    @Published private(set) var isWatchAppInstalled: Bool = false
    @Published private(set) var isWatchReachable: Bool = false
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var lastSyncDate: Date?
    
    private var session: WCSession?
    private var cancellables = Set<AnyCancellable>()
    private var timerObserver: AnyCancellable?
    
    private override init() {
        super.init()
        setupSession()
        observeTimerChanges()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            log("WCSession not supported on this device")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        log("WCSession activation requested")
    }
    
    private func observeTimerChanges() {
        timerObserver = FocusTimerManager.shared.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.pushStateToWatch()
                }
            }
    }
    
    func pushStateToWatch() async {
        guard let session = session,
              session.activationState == .activated,
              session.isWatchAppInstalled else {
            return
        }
        
        let userAuth = createUserAuthSyncData()
        let timerState = createTimerSyncState()
        let habits = await loadHabitSyncData()
        let dietPlans = await loadDietPlanSyncData()
        let workoutPlans = await loadWorkoutPlanSyncData()
        
        let payload = WatchSyncPayload(
            timestamp: Date(),
            userAuth: userAuth,
            timerState: timerState,
            habits: habits,
            healthSummary: nil,
            dietPlans: dietPlans,
            workoutPlans: workoutPlans
        )
        
        guard let dict = payload.toDictionary() else {
            log("Failed to encode payload")
            return
        }
        
        do {
            try session.updateApplicationContext([WatchSyncPayload.contextKey: dict])
            lastSyncDate = Date()
            cacheStateForComplications(payload)
            log("Pushed state to Watch: logged in: \(userAuth.isLoggedIn), \(habits.count) habits, \(dietPlans.count) diet plans, \(workoutPlans.count) workout plans")
        } catch {
            log("Failed to push state: \(error.localizedDescription)")
        }
    }
    
    private func createUserAuthSyncData() -> UserAuthSyncData {
        let userId = SessionManager.shared.currentUserID
        let displayName = SessionManager.shared.currentUserDisplayName
        return UserAuthSyncData(
            isLoggedIn: userId != nil,
            userId: userId,
            displayName: displayName,
            photoURL: nil
        )
    }
    
    private func createTimerSyncState() -> TimerSyncState {
        let manager = FocusTimerManager.shared
        return TimerSyncState(
            isActive: manager.isActive,
            isPaused: manager.isPaused,
            isOnBreak: manager.isOnBreak,
            remainingSeconds: manager.remainingSeconds,
            totalSeconds: manager.totalSeconds,
            habitId: manager.activeHabit?.id.uuidString,
            habitName: manager.activeHabit?.name,
            habitIcon: manager.activeHabit?.icon ?? "brain.head.profile",
            endDate: manager.isActive && !manager.isPaused
                ? Date().addingTimeInterval(TimeInterval(manager.remainingSeconds))
                : nil
        )
    }
    
    private func loadHabitSyncData() async -> [HabitSyncData] {
        do {
            let userId = SessionManager.shared.currentUserID
            let habits = try await HabitStore.shared.loadHabits(userId: userId)
            let today = Calendar.current.startOfDay(for: Date())
            
            return habits.map { habit in
                let isCompletedToday = habit.completionDates.contains { date in
                    Calendar.current.startOfDay(for: date) == today
                }
                
                return HabitSyncData(
                    id: habit.id.uuidString,
                    name: habit.name,
                    icon: habit.icon,
                    category: habit.category.rawValue,
                    currentStreak: habit.currentStreak,
                    isCompletedToday: isCompletedToday,
                    suggestedDurationMinutes: habit.suggestedDurationMinutes,
                    completionDates: habit.completionDates
                )
            }
        } catch {
            log("Failed to load habits: \(error.localizedDescription)")
            return []
        }
    }
    
    private func loadDietPlanSyncData() async -> [DietPlanSyncData] {
        guard let userId = SessionManager.shared.currentUserID else { return [] }
        
        do {
            let plans = try await DietPlanService.shared.loadActivePlansForUser(userId: userId)
            let today = Calendar.current.startOfDay(for: Date())
            
            return plans.compactMap { plan -> DietPlanSyncData? in
                let todayPlan = plan.dailyPlans.first { dailyPlan in
                    guard let actualDate = dailyPlan.actualDate else { return false }
                    return Calendar.current.startOfDay(for: actualDate) == today
                }
                
                let todayMeals = todayPlan?.sortedMeals.map { meal in
                    MealSyncData(
                        id: meal.id.uuidString,
                        type: meal.type.rawValue,
                        recipeName: meal.recipe.name,
                        calories: meal.nutrition.calories,
                        isDone: meal.isDone
                    )
                } ?? []
                
                return DietPlanSyncData(
                    id: plan.id,
                    weekRange: plan.formattedWeekRange,
                    avgCaloriesPerDay: plan.summary.avgCaloriesPerDay,
                    totalDays: plan.totalDays,
                    todayMeals: todayMeals,
                    isCurrentWeek: plan.isCurrentWeek
                )
            }
        } catch {
            log("Failed to load diet plans: \(error.localizedDescription)")
            return []
        }
    }
    
    private func loadWorkoutPlanSyncData() async -> [WorkoutPlanSyncData] {
        guard let userId = SessionManager.shared.currentUserID else { return [] }
        
        do {
            let plans = try await WorkoutPlanService.shared.loadActivePlansForUser(userId: userId)
            let today = Calendar.current.startOfDay(for: Date())
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            return plans.map { doc -> WorkoutPlanSyncData in
                let todayWorkout = doc.plan.days.first { day in
                    guard let dayDate = dateFormatter.date(from: day.date) else { return false }
                    return Calendar.current.startOfDay(for: dayDate) == today
                }
                
                let todayWorkoutSync: WorkoutDaySyncData? = todayWorkout.map { day in
                    WorkoutDaySyncData(
                        id: day.id.uuidString,
                        day: day.day,
                        focus: day.formattedFocus,
                        isRestDay: day.isRestDay,
                        exerciseCount: day.exercises.count,
                        estimatedMinutes: day.estimatedDurationMinutes,
                        exercises: day.exercises.prefix(5).map { exercise in
                            ExerciseSyncData(
                                id: exercise.id.uuidString,
                                name: exercise.name,
                                setsReps: exercise.formattedSetsReps
                            )
                        }
                    )
                }
                
                return WorkoutPlanSyncData(
                    id: doc.id,
                    title: doc.plan.title,
                    planType: doc.planType.rawValue,
                    weekRange: doc.formattedWeekRange,
                    workoutDaysCount: doc.plan.workoutDaysCount,
                    todayWorkout: todayWorkoutSync,
                    isCurrentWeek: doc.isCurrentWeek
                )
            }
        } catch {
            log("Failed to load workout plans: \(error.localizedDescription)")
            return []
        }
    }
    
    private func cacheStateForComplications(_ payload: WatchSyncPayload) {
        guard let defaults = UserDefaults(suiteName: WatchSyncConstants.appGroupIdentifier),
              let data = try? JSONEncoder().encode(payload) else {
            return
        }
        defaults.set(data, forKey: WatchSyncConstants.cachedStateKey)
    }
    
    private func handleIncomingMessage(_ message: [String: Any]) async {
        guard let commandDict = message["command"] as? [String: Any],
              let payload = WatchCommandPayload.from(dictionary: commandDict) else {
            log("Invalid command payload received")
            return
        }
        
        log("Received command: \(payload.command.rawValue)")
        
        switch payload.command {
        case .startTimer:
            if let habitId = payload.habitId {
                await startTimerForHabit(id: habitId, duration: payload.durationMinutes)
            }
            
        case .pauseTimer:
            FocusTimerManager.shared.pause()
            
        case .resumeTimer:
            FocusTimerManager.shared.resume()
            
        case .stopTimer:
            FocusTimerManager.shared.stop()
            
        case .completeHabit:
            if let habitId = payload.habitId {
                await toggleHabitCompletion(id: habitId, complete: true)
            }
            
        case .uncompleteHabit:
            if let habitId = payload.habitId {
                await toggleHabitCompletion(id: habitId, complete: false)
            }
            
        case .requestSync:
            await pushStateToWatch()
            
        case .submitPairingCode:
            if let code = payload.pairingCode {
                handlePairingCodeSubmission(code)
            }
        }
    }
    
    private func handlePairingCodeSubmission(_ code: String) {
        let isValid = WatchPairingService.shared.validateCode(code)
        if !isValid {
            sendPairingDenied()
        }
    }
    
    func sendPairingConfirmation() async {
        guard let session = session, session.isReachable else {
            log("Cannot send pairing confirmation - Watch not reachable")
            return
        }
        
        let payload = PhoneToWatchPayload(command: .pairingConfirmed)
        guard let dict = payload.toDictionary() else { return }
        
        session.sendMessage(["phoneCommand": dict], replyHandler: nil) { [weak self] error in
            Task { @MainActor in
                self?.log("Failed to send pairing confirmation: \(error.localizedDescription)")
            }
        }
        
        await pushStateToWatch()
        log("Pairing confirmation sent to Watch")
    }
    
    func sendPairingDenied() {
        guard let session = session, session.isReachable else { return }
        
        let payload = PhoneToWatchPayload(command: .pairingDenied)
        guard let dict = payload.toDictionary() else { return }
        
        session.sendMessage(["phoneCommand": dict], replyHandler: nil, errorHandler: nil)
        log("Pairing denied sent to Watch")
    }
    
    func sendUnpairCommand() {
        guard let session = session, session.isReachable else { return }
        
        let payload = PhoneToWatchPayload(command: .unpair)
        guard let dict = payload.toDictionary() else { return }
        
        session.sendMessage(["phoneCommand": dict], replyHandler: nil, errorHandler: nil)
        log("Unpair command sent to Watch")
    }
    
    private func startTimerForHabit(id: String, duration: Int?) async {
        guard let userId = SessionManager.shared.currentUserID else { return }
        
        do {
            guard let habit = try await HabitFirestoreService.shared.loadHabit(byId: id, userId: userId) else {
                log("Habit not found: \(id)")
                return
            }
            
            if let duration = duration {
                FocusTimerManager.shared.startTimer(for: habit, durationMinutes: duration)
            } else {
                FocusTimerManager.shared.startTimer(for: habit)
            }
            log("Started timer for habit: \(habit.name)")
        } catch {
            log("Failed to start timer: \(error.localizedDescription)")
        }
    }
    
    private func toggleHabitCompletion(id: String, complete: Bool) async {
        guard let uuid = UUID(uuidString: id),
              let userId = SessionManager.shared.currentUserID else { return }
        
        do {
            _ = try await HabitFirestoreService.shared.toggleHabitCompletion(
                habitId: id,
                userId: userId,
                date: Date()
            )
            
            let habits = try await HabitFirestoreService.shared.loadHabits(userId: userId)
            guard let habit = habits.first(where: { $0.id == uuid }) else { return }
            
            if complete {
                log("Completed habit: \(habit.name)")
            } else {
                log("Uncompleted habit: \(habit.name)")
            }
            
            await pushStateToWatch()
        } catch {
            log("Failed to toggle habit: \(error.localizedDescription)")
        }
    }
    
    private func saveFocusSession(wasCompleted: Bool) {
        let manager = FocusTimerManager.shared
        
        guard let userId = SessionManager.shared.currentUserID,
              let habit = manager.activeHabit,
              let sessionStartTime = manager.sessionStartTime else {
            return
        }
        
        let elapsedSeconds = manager.totalSeconds - manager.remainingSeconds
        guard elapsedSeconds > 0 else { return }
        
        let session = FocusSession(
            id: UUID().uuidString,
            userId: userId,
            habitId: habit.id.uuidString,
            habitName: habit.name,
            habitIcon: habit.icon,
            startedAt: sessionStartTime,
            endedAt: Date(),
            durationSeconds: elapsedSeconds,
            wasCompleted: wasCompleted
        )
        
        Task {
            do {
                try await FocusSessionService.shared.saveSession(session, userId: userId)
                log("Saved focus session from watch: \(session.durationMinutes)min, completed: \(session.wasCompleted)")
            } catch {
                log("Failed to save focus session from watch: \(error.localizedDescription)")
            }
        }
    }
    
    private func processQueuedCommands() {
        guard let defaults = UserDefaults(suiteName: WatchSyncConstants.appGroupIdentifier),
              let data = defaults.data(forKey: WatchSyncConstants.pendingCommandsKey),
              let commands = try? JSONDecoder().decode([WatchCommandPayload].self, from: data) else {
            return
        }
        
        defaults.removeObject(forKey: WatchSyncConstants.pendingCommandsKey)
        
        Task {
            for command in commands {
                await handleIncomingMessage(["command": command.toDictionary() ?? [:]])
            }
        }
    }
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [WatchConnectivityService] \(message)")
        #endif
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isPaired = session.isPaired
            isWatchAppInstalled = session.isWatchAppInstalled
            isWatchReachable = session.isReachable
            
            if activationState == .activated {
                log("WCSession activated - paired: \(isPaired), installed: \(isWatchAppInstalled)")
                await pushStateToWatch()
            }
            
            if let error = error {
                log("Activation error: \(error.localizedDescription)")
            }
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            log("Session became inactive")
        }
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            log("Session deactivated, reactivating...")
            session.activate()
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
            log("Reachability changed: \(isWatchReachable)")
            
            if session.isReachable {
                await pushStateToWatch()
            }
        }
    }
    
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            isPaired = session.isPaired
            isWatchAppInstalled = session.isWatchAppInstalled
            log("Watch state changed - paired: \(isPaired), installed: \(isWatchAppInstalled)")
        }
    }
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            await handleIncomingMessage(message)
            replyHandler(["status": "ok", "timestamp": Date().timeIntervalSince1970])
        }
    }
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            await handleIncomingMessage(message)
        }
    }
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            log("Received user info transfer")
            await handleIncomingMessage(userInfo)
        }
    }
}

#endif

