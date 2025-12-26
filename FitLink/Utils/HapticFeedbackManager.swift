import UIKit

final class HapticFeedbackManager {
    
    static let shared = HapticFeedbackManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        prepareGenerators()
    }
    
    private func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        selection.prepare()
        notification.prepare()
    }
    
    private var isEnabled: Bool {
        FeatureFlags.isHapticFeedbackEnabled
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        case .heavy:
            impactHeavy.impactOccurred()
        case .soft:
            impactSoft.impactOccurred()
        case .rigid:
            impactRigid.impactOccurred()
        @unknown default:
            impactMedium.impactOccurred()
        }
    }
    
    func selectionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        notification.notificationOccurred(type)
    }
    
    func success() {
        notification(.success)
    }
    
    func warning() {
        notification(.warning)
    }
    
    func error() {
        notification(.error)
    }
    
    func buttonTap() {
        impact(.light)
    }
    
    func toggleSwitch() {
        impact(.medium)
    }
    
    func dateSelected() {
        selectionChanged()
    }
    
    func taskCompleted() {
        success()
    }
    
    func habitChecked() {
        impact(.rigid)
    }
    
    func pullToRefresh() {
        impact(.soft)
    }
    
    func deleteAction() {
        notification(.warning)
    }
    
    func timerTick() {
        impact(.soft)
    }
}

import SwiftUI

extension View {
    func hapticOnTap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                HapticFeedbackManager.shared.impact(style)
            }
        )
    }
    
    func hapticOnChange<V: Equatable>(of value: V, perform: @escaping () -> Void = {}) -> some View {
        self.onChange(of: value) { _, _ in
            HapticFeedbackManager.shared.selectionChanged()
            perform()
        }
    }
}
