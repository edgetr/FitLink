import UIKit
import SwiftUI
import Combine

@MainActor
final class FocusTimerWindowController {
    static let shared = FocusTimerWindowController()
    
    private var overlayWindow: UIWindow?
    private var hostingController: UIHostingController<FocusTimerOverlayContent>?
    private var panGesture: UIPanGestureRecognizer?
    private var cancellables = Set<AnyCancellable>()
    
    private var currentPosition: CGPoint = .zero
    private var dragStartPosition: CGPoint = .zero
    
    private let overlayExpandedSize = CGSize(width: 220, height: 160)
    private let overlayCompactSize = CGSize(width: 130, height: 44)
    
    @Published private var isExpanded: Bool = true
    
    private var currentSize: CGSize {
        isExpanded ? overlayExpandedSize : overlayCompactSize
    }
    
    private init() {
        setupTimerObserver()
    }
    
    private func setupTimerObserver() {
        FocusTimerManager.shared.$isActive
            .receive(on: RunLoop.main)
            .sink { [weak self] isActive in
                if isActive {
                    self?.showOverlay()
                } else {
                    self?.hideOverlay()
                }
            }
            .store(in: &cancellables)
    }
    
    func showOverlay() {
        guard overlayWindow == nil else { return }
        
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else { return }
        
        let window = PassthroughWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isHidden = false
        
        let content = FocusTimerOverlayContent(
            isExpanded: Binding(
                get: { [weak self] in self?.isExpanded ?? true },
                set: { [weak self] newValue in
                    self?.isExpanded = newValue
                    self?.updateOverlayFrame(animated: true)
                }
            )
        )
        
        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.layer.shadowColor = UIColor.black.cgColor
        hosting.view.layer.shadowOpacity = 0.15
        hosting.view.layer.shadowRadius = 12
        hosting.view.layer.shadowOffset = CGSize(width: 0, height: 6)
        
        let screenBounds = windowScene.screen.bounds
        let initialX = screenBounds.width / 2
        let initialY = screenBounds.height - 200
        currentPosition = CGPoint(x: initialX, y: initialY)
        
        hosting.view.frame = CGRect(
            x: currentPosition.x - currentSize.width / 2,
            y: currentPosition.y - currentSize.height / 2,
            width: currentSize.width,
            height: currentSize.height
        )
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        hosting.view.addGestureRecognizer(pan)
        panGesture = pan
        
        window.addSubview(hosting.view)
        window.makeKeyAndVisible()
        
        hosting.view.alpha = 0
        hosting.view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            hosting.view.alpha = 1
            hosting.view.transform = .identity
        }
        
        overlayWindow = window
        hostingController = hosting
    }
    
    func hideOverlay() {
        guard let hosting = hostingController else {
            overlayWindow?.isHidden = true
            overlayWindow = nil
            return
        }
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            hosting.view.alpha = 0
            hosting.view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { [weak self] _ in
            self?.overlayWindow?.isHidden = true
            self?.overlayWindow = nil
            self?.hostingController = nil
            self?.panGesture = nil
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        
        switch gesture.state {
        case .began:
            dragStartPosition = currentPosition
            
        case .changed:
            let translation = gesture.translation(in: view.superview)
            let newX = dragStartPosition.x + translation.x
            let newY = dragStartPosition.y + translation.y
            currentPosition = clampPosition(CGPoint(x: newX, y: newY))
            
            view.center = currentPosition
            
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view.superview)
            let projectedX = currentPosition.x + velocity.x * 0.1
            let projectedY = currentPosition.y + velocity.y * 0.1
            let finalPosition = clampPosition(CGPoint(x: projectedX, y: projectedY))
            
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2) {
                view.center = finalPosition
            }
            currentPosition = finalPosition
            
        default:
            break
        }
    }
    
    private func clampPosition(_ pos: CGPoint) -> CGPoint {
        guard let window = overlayWindow else { return pos }
        
        let bounds = window.screen.bounds
        let safeArea = window.safeAreaInsets
        let padding: CGFloat = 10
        let halfWidth = currentSize.width / 2
        let halfHeight = currentSize.height / 2
        
        let minX = halfWidth + padding
        let maxX = bounds.width - halfWidth - padding
        let minY = halfHeight + safeArea.top + padding
        let maxY = bounds.height - halfHeight - safeArea.bottom - padding
        
        return CGPoint(
            x: max(minX, min(maxX, pos.x)),
            y: max(minY, min(maxY, pos.y))
        )
    }
    
    private func updateOverlayFrame(animated: Bool) {
        guard let hosting = hostingController else { return }
        
        let newFrame = CGRect(
            x: currentPosition.x - currentSize.width / 2,
            y: currentPosition.y - currentSize.height / 2,
            width: currentSize.width,
            height: currentSize.height
        )
        
        if animated {
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3) {
                hosting.view.frame = newFrame
            }
        } else {
            hosting.view.frame = newFrame
        }
        
        currentPosition = clampPosition(currentPosition)
    }
}

private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event) else { return nil }
        return hitView == self ? nil : hitView
    }
}
