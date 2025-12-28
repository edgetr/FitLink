import SwiftUI
import UIKit

struct MemoryToastOverlay: View {
    @EnvironmentObject var memoryToastManager: MemoryToastManager
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if memoryToastManager.isShowingToast, let memory = memoryToastManager.currentToast {
                    MemoryToastView(memory: memory) {
                        memoryToastManager.dismissCurrentToast()
                    }
                    .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top + 10 : 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.height < -10 {
                                    memoryToastManager.dismissCurrentToast()
                                }
                            }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: memoryToastManager.isShowingToast)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: memoryToastManager.currentToast)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(memoryToastManager.isShowingToast)
    }
}

#Preview {
    let manager = MemoryToastManager.shared
    
    ZStack {
        Color(UIColor.systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack {
            Button("Trigger Success Toast") {
                manager.currentToast = Memory(
                    type: .preferredExercise,
                    value: "Running",
                    source: .manualEntry
                )
                withAnimation {
                    manager.isShowingToast = true
                }
            }
            
            Button("Trigger Warning Toast") {
                manager.currentToast = Memory(
                    type: .avoidedIngredient,
                    value: "Gluten",
                    source: .manualEntry
                )
                withAnimation {
                    manager.isShowingToast = true
                }
            }
        }
        
        MemoryToastOverlay()
            .environmentObject(manager)
    }
}
