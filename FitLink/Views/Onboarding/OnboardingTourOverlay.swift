import SwiftUI

struct OnboardingTourOverlay: View {
    @ObservedObject var coordinator: OnboardingTourCoordinator
    let targetAnchors: [String: Anchor<CGRect>]
    
    @State private var tooltipSize: CGSize = CGSize(width: 300, height: 140)
    @State private var hasInitializedSize: Bool = false
    
    var body: some View {
        GeometryReader { proxy in
            if coordinator.isShowingTour, let step = coordinator.currentStep {
                ZStack {
                    spotlightBackground(proxy: proxy, step: step)
                    tooltipCard(proxy: proxy, step: step)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Spotlight Background
    
    @ViewBuilder
    private func spotlightBackground(proxy: GeometryProxy, step: OnboardingTourStep) -> some View {
        if let anchor = targetAnchors[step.targetElementID] {
            let targetRect = proxy[anchor]
            let expandedRect = targetRect.insetBy(dx: -8, dy: -8)
            
            SpotlightShape(cutoutRect: expandedRect, cornerRadius: GlassTokens.Radius.card + 4)
                .fill(style: FillStyle(eoFill: true))
                .foregroundStyle(Color.black.opacity(0.7))
                .onTapGesture {
                    if step.completionRule == .tapTarget {
                        coordinator.handleTargetTapped(step.targetElementID)
                    }
                }
        } else {
            Color.black.opacity(0.7)
        }
    }
    
    // MARK: - Tooltip Card
    
    @ViewBuilder
    private func tooltipCard(proxy: GeometryProxy, step: OnboardingTourStep) -> some View {
        let screenHeight = proxy.size.height
        let screenWidth = proxy.size.width
        
        let targetRect: CGRect? = {
            guard let anchor = targetAnchors[step.targetElementID] else { return nil }
            return proxy[anchor]
        }()
        
        let tooltipPosition = calculateTooltipPosition(
            targetRect: targetRect,
            screenWidth: screenWidth,
            screenHeight: screenHeight
        )
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(step.title)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button {
                    coordinator.skipTour()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(step.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                progressIndicator
                
                Spacer()
                
                navigationButtons(step: step)
            }
        }
        .padding(GlassTokens.Padding.standard)
        .frame(maxWidth: min(screenWidth - 40, 340))
        .background(
            RoundedRectangle(cornerRadius: GlassTokens.Radius.card)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: GlassTokens.Radius.card)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: TooltipSizeKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(TooltipSizeKey.self) { size in
            if !hasInitializedSize || abs(size.height - tooltipSize.height) > 20 {
                tooltipSize = size
                hasInitializedSize = true
            }
        }
        .position(tooltipPosition)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: coordinator.currentStepIndex)
    }
    
    private var progressIndicator: some View {
        HStack(spacing: 6) {
            if let tour = coordinator.activeTour {
                ForEach(0..<tour.steps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= coordinator.currentStepIndex ? Color(red: 0.2, green: 0.78, blue: 0.65) : Color.gray.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }
    
    @ViewBuilder
    private func navigationButtons(step: OnboardingTourStep) -> some View {
        HStack(spacing: GlassTokens.Padding.small) {
            if coordinator.hasPreviousStep {
                Button {
                    coordinator.previousStep()
                } label: {
                    Text("Back")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                        )
                }
            }
            
            Button {
                if step.completionRule == .tapNext || step.completionRule == .tapTarget {
                    coordinator.nextStep()
                }
            } label: {
                Text(coordinator.hasNextStep ? "Next" : "Done")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.78, blue: 0.65), Color(red: 0.15, green: 0.58, blue: 0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(red: 0.15, green: 0.58, blue: 0.75).opacity(0.4), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Position Calculation
    
    private func calculateTooltipPosition(
        targetRect: CGRect?,
        screenWidth: CGFloat,
        screenHeight: CGFloat
    ) -> CGPoint {
        guard let targetRect = targetRect else {
            return CGPoint(x: screenWidth / 2, y: screenHeight / 2)
        }
        
        let tooltipHeight = max(tooltipSize.height, 140)
        let tooltipWidth = min(screenWidth - 40, 340)
        let verticalPadding: CGFloat = 16
        let safeAreaTop: CGFloat = 60
        let safeAreaBottom: CGFloat = 40
        
        let spaceAbove = targetRect.minY - safeAreaTop
        let spaceBelow = screenHeight - targetRect.maxY - safeAreaBottom
        
        let showAbove = spaceBelow < tooltipHeight + verticalPadding && spaceAbove > spaceBelow
        
        let yPosition: CGFloat
        if showAbove {
            yPosition = targetRect.minY - tooltipHeight / 2 - verticalPadding
        } else {
            yPosition = targetRect.maxY + tooltipHeight / 2 + verticalPadding
        }
        
        var xPosition = targetRect.midX
        let halfWidth = tooltipWidth / 2
        let minX = halfWidth + 20
        let maxX = screenWidth - halfWidth - 20
        xPosition = max(minX, min(maxX, xPosition))
        
        return CGPoint(x: xPosition, y: yPosition)
    }
}

// MARK: - Spotlight Shape

struct SpotlightShape: Shape {
    let cutoutRect: CGRect
    let cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: cutoutRect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return path
    }
}

// MARK: - Preference Keys

private struct TooltipSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - View Extension

extension View {
    func onboardingTourOverlay() -> some View {
        self.modifier(OnboardingTourOverlayModifier())
    }
}

private struct OnboardingTourOverlayModifier: ViewModifier {
    @StateObject private var coordinator = OnboardingTourCoordinator.shared
    
    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(OnboardingTargetKey.self) { anchors in
                OnboardingTourOverlay(
                    coordinator: coordinator,
                    targetAnchors: anchors
                )
            }
    }
}
