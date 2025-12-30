import Foundation
import WatchConnectivity
import Combine

#if os(watchOS)

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    
    static let shared = WatchSessionManager()
    
    @Published private(set) var userAuth: UserAuthSyncData = .notLoggedIn
    @Published private(set) var timerState: TimerSyncState = .idle
    @Published private(set) var habits: [HabitSyncData] = []
    @Published private(set) var healthSummary: HealthSummaryData?
    @Published private(set) var dietPlans: [DietPlanSyncData] = []
    @Published private(set) var workoutPlans: [WorkoutPlanSyncData] = []
    @Published private(set) var isPhoneReachable: Bool = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pairingState: PairingState = .notPaired
    
    enum PairingState: Equatable {
        case notPaired
        case waitingForConfirmation
        case paired
        case denied
    }
    
    var isLoggedIn: Bool { userAuth.isLoggedIn }
    
    private var session: WCSession?
    private var pendingCommands: [WatchCommandPayload] = []
    private var localTimerCancellable: AnyCancellable?
    
    private override init() {
        super.init()
        loadCachedState()
        setupSession()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            log("WCSession not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    private func loadCachedState() {
        guard let defaults = UserDefaults(suiteName: WatchSyncConstants.appGroupIdentifier),
              let data = defaults.data(forKey: WatchSyncConstants.cachedStateKey),
              let payload = try? JSONDecoder().decode(WatchSyncPayload.self, from: data) else {
            return
        }
        
        applyPayload(payload)
        log("Loaded cached state: \(habits.count) habits")
    }
    
    private func cacheState(_ payload: WatchSyncPayload) {
        guard let defaults = UserDefaults(suiteName: WatchSyncConstants.appGroupIdentifier),
              let data = try? JSONEncoder().encode(payload) else {
            return
        }
        defaults.set(data, forKey: WatchSyncConstants.cachedStateKey)
    }
    
    private func applyPayload(_ payload: WatchSyncPayload) {
        userAuth = payload.userAuth
        if let timer = payload.timerState {
            timerState = timer
            startLocalTimerIfNeeded()
        }
        habits = payload.habits
        healthSummary = payload.healthSummary
        dietPlans = payload.dietPlans
        workoutPlans = payload.workoutPlans
        lastSyncDate = payload.timestamp
    }
    
    private func handlePhoneCommand(_ payload: PhoneToWatchPayload) {
        switch payload.command {
        case .pairingConfirmed:
            pairingState = .paired
            log("Pairing confirmed")
            requestSync()
            
        case .pairingDenied:
            pairingState = .denied
            log("Pairing denied")
            
        case .unpair:
            pairingState = .notPaired
            log("Unpaired")
            habits = []
            userAuth = .notLoggedIn
        }
    }
    
    private func startLocalTimerIfNeeded() {
        localTimerCancellable?.cancel()
        
        guard timerState.isRunning, let endDate = timerState.endDate, endDate > Date() else {
            return
        }
        
        localTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self = self else { return }
                
                let remaining = Int(endDate.timeIntervalSince(now))
                if remaining > 0 {
                    self.timerState = TimerSyncState(
                        isActive: self.timerState.isActive,
                        isPaused: self.timerState.isPaused,
                        isOnBreak: self.timerState.isOnBreak,
                        remainingSeconds: remaining,
                        totalSeconds: self.timerState.totalSeconds,
                        habitId: self.timerState.habitId,
                        habitName: self.timerState.habitName,
                        habitIcon: self.timerState.habitIcon,
                        endDate: endDate
                    )
                } else {
                    self.localTimerCancellable?.cancel()
                    self.timerState = .idle
                }
            }
    }
    
    func sendCommand(_ command: WatchCommand, habitId: String? = nil, durationMinutes: Int? = nil, pairingCode: String? = nil) {
        let payload = WatchCommandPayload(
            command: command,
            habitId: habitId,
            durationMinutes: durationMinutes,
            pairingCode: pairingCode
        )
        
        guard let session = session,
              session.activationState == .activated else {
            queueCommand(payload)
            return
        }
        
        if session.isReachable {
            sendMessageImmediate(payload)
        } else {
            sendUserInfoTransfer(payload)
        }
    }
    
    private func sendMessageImmediate(_ payload: WatchCommandPayload) {
        guard let dict = payload.toDictionary() else { return }
        
        session?.sendMessage(["command": dict], replyHandler: { [weak self] response in
            Task { @MainActor in
                self?.log("Command acknowledged: \(payload.command.rawValue)")
                if payload.command == .submitPairingCode {
                    self?.log("Pairing code sent successfully, waiting for confirmation...")
                }
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.log("Command failed: \(error.localizedDescription)")
                self?.log("Trying transferUserInfo as fallback...")
                self?.sendUserInfoTransfer(payload)
            }
        })
    }
    
    private func sendUserInfoTransfer(_ payload: WatchCommandPayload) {
        guard let dict = payload.toDictionary() else { return }
        session?.transferUserInfo(["command": dict])
        log("Queued command via userInfo: \(payload.command.rawValue)")
    }
    
    private func queueCommand(_ payload: WatchCommandPayload) {
        pendingCommands.append(payload)
        savePendingCommands()
        log("Command queued for later: \(payload.command.rawValue)")
    }
    
    private func savePendingCommands() {
        guard let defaults = UserDefaults(suiteName: WatchSyncConstants.appGroupIdentifier),
              let data = try? JSONEncoder().encode(pendingCommands) else {
            return
        }
        defaults.set(data, forKey: WatchSyncConstants.pendingCommandsKey)
    }
    
    private func flushPendingCommands() {
        guard !pendingCommands.isEmpty, session?.isReachable == true else { return }
        
        let commands = pendingCommands
        pendingCommands.removeAll()
        savePendingCommands()
        
        for payload in commands {
            sendMessageImmediate(payload)
        }
        
        log("Flushed \(commands.count) pending commands")
    }
    
    func requestSync() {
        sendCommand(.requestSync)
    }
    
    func submitPairingCode(_ code: String) {
        pairingState = .waitingForConfirmation
        sendCommand(.submitPairingCode, pairingCode: code)
    }
    
    func resetPairingState() {
        pairingState = .notPaired
    }
    
    func startTimer(for habit: HabitSyncData) {
        timerState = TimerSyncState(
            isActive: true,
            isPaused: false,
            isOnBreak: false,
            remainingSeconds: habit.suggestedDurationMinutes * 60,
            totalSeconds: habit.suggestedDurationMinutes * 60,
            habitId: habit.id,
            habitName: habit.name,
            habitIcon: habit.icon,
            endDate: Date().addingTimeInterval(TimeInterval(habit.suggestedDurationMinutes * 60))
        )
        startLocalTimerIfNeeded()
        sendCommand(.startTimer, habitId: habit.id, durationMinutes: habit.suggestedDurationMinutes)
    }
    
    func pauseTimer() {
        guard timerState.isActive else { return }
        
        localTimerCancellable?.cancel()
        timerState = TimerSyncState(
            isActive: timerState.isActive,
            isPaused: true,
            isOnBreak: timerState.isOnBreak,
            remainingSeconds: timerState.remainingSeconds,
            totalSeconds: timerState.totalSeconds,
            habitId: timerState.habitId,
            habitName: timerState.habitName,
            habitIcon: timerState.habitIcon,
            endDate: nil
        )
        sendCommand(.pauseTimer)
    }
    
    func resumeTimer() {
        guard timerState.isActive, timerState.isPaused else { return }
        
        let newEndDate = Date().addingTimeInterval(TimeInterval(timerState.remainingSeconds))
        timerState = TimerSyncState(
            isActive: timerState.isActive,
            isPaused: false,
            isOnBreak: timerState.isOnBreak,
            remainingSeconds: timerState.remainingSeconds,
            totalSeconds: timerState.totalSeconds,
            habitId: timerState.habitId,
            habitName: timerState.habitName,
            habitIcon: timerState.habitIcon,
            endDate: newEndDate
        )
        startLocalTimerIfNeeded()
        sendCommand(.resumeTimer)
    }
    
    func stopTimer() {
        localTimerCancellable?.cancel()
        timerState = .idle
        sendCommand(.stopTimer)
    }
    
    func toggleHabitCompletion(_ habit: HabitSyncData) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            let newCompleted = !habits[index].isCompletedToday
            habits[index] = HabitSyncData(
                id: habit.id,
                name: habit.name,
                icon: habit.icon,
                category: habit.category,
                currentStreak: newCompleted ? habit.currentStreak + 1 : max(0, habit.currentStreak - 1),
                isCompletedToday: newCompleted,
                suggestedDurationMinutes: habit.suggestedDurationMinutes,
                completionDates: habit.completionDates
            )
            
            sendCommand(newCompleted ? .completeHabit : .uncompleteHabit, habitId: habit.id)
        }
    }
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [WatchSessionManager] \(message)")
        #endif
    }
}

extension WatchSessionManager: WCSessionDelegate {
    
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isPhoneReachable = session.isReachable
            
            if activationState == .activated {
                log("WCSession activated, reachable: \(isPhoneReachable)")
                flushPendingCommands()
                requestSync()
            }
            
            if let error = error {
                log("Activation error: \(error.localizedDescription)")
            }
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isPhoneReachable = session.isReachable
            log("Reachability changed: \(isPhoneReachable)")
            
            if session.isReachable {
                flushPendingCommands()
            }
        }
    }
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            guard let dict = applicationContext[WatchSyncPayload.contextKey] as? [String: Any],
                  let payload = WatchSyncPayload.from(dictionary: dict) else {
                log("Invalid application context received")
                return
            }
            
            applyPayload(payload)
            cacheState(payload)
            log("Received application context: \(habits.count) habits")
        }
    }
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            if let dict = message[WatchSyncPayload.contextKey] as? [String: Any],
               let payload = WatchSyncPayload.from(dictionary: dict) {
                applyPayload(payload)
                cacheState(payload)
                log("Received message with payload")
            } else if let dict = message["phoneCommand"] as? [String: Any],
                      let payload = PhoneToWatchPayload.from(dictionary: dict) {
                handlePhoneCommand(payload)
            }
        }
    }
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in
            if let dict = userInfo["phoneCommand"] as? [String: Any],
               let payload = PhoneToWatchPayload.from(dictionary: dict) {
                handlePhoneCommand(payload)
            }
        }
    }
}

#endif
