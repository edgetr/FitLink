//
//  FocusTimerSharedState.swift
//  FitLinkLiveActivity
//
//  Created by Gökay Ege Süren on 25.12.2025.
//

import Foundation
import SwiftUI

// MARK: - Timer State

enum FocusTimerState: String, Codable {
    case running
    case paused
    case breakTime
    case finished
    
    var displayName: String {
        switch self {
        case .running: return "Focus"
        case .paused: return "Paused"
        case .breakTime: return "Break"
        case .finished: return "Done"
        }
    }
    
    var icon: String {
        switch self {
        case .running: return "brain.head.profile"
        case .paused: return "pause.fill"
        case .breakTime: return "cup.and.saucer.fill"
        case .finished: return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .running: return .cyan
        case .paused: return .orange
        case .breakTime: return .blue
        case .finished: return .green
        }
    }
}

// MARK: - Shared State Model

struct FocusTimerSharedState: Codable {
    let isActive: Bool
    let habitId: String?
    let habitName: String
    let timeRemaining: Int
    let timerState: FocusTimerState
    let lastUpdated: Date
    
    static let appGroupIdentifier = "group.com.edgetr.FitLink"
    static let stateKey = "focusTimerState"
    static let commandKey = "focusTimerCommand"
    
    static func read() -> FocusTimerSharedState? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: stateKey) else {
            return nil
        }
        
        return try? JSONDecoder().decode(FocusTimerSharedState.self, from: data)
    }
    
    func write() {
        guard let defaults = UserDefaults(suiteName: FocusTimerSharedState.appGroupIdentifier),
              let data = try? JSONEncoder().encode(self) else {
            return
        }
        
        defaults.set(data, forKey: FocusTimerSharedState.stateKey)
    }
    
    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.removeObject(forKey: stateKey)
    }
}

// MARK: - Command Model

enum FocusTimerCommand: String, Codable {
    case start
    case pause
    case resume
    case stop
    
    static func read() -> FocusTimerCommand? {
        guard let defaults = UserDefaults(suiteName: FocusTimerSharedState.appGroupIdentifier),
              let rawValue = defaults.string(forKey: FocusTimerSharedState.commandKey) else {
            return nil
        }
        
        return FocusTimerCommand(rawValue: rawValue)
    }
    
    func write() {
        guard let defaults = UserDefaults(suiteName: FocusTimerSharedState.appGroupIdentifier) else {
            return
        }
        
        defaults.set(self.rawValue, forKey: FocusTimerSharedState.commandKey)
    }
    
    static func clear() {
        guard let defaults = UserDefaults(suiteName: FocusTimerSharedState.appGroupIdentifier) else { return }
        defaults.removeObject(forKey: FocusTimerSharedState.commandKey)
    }
}
