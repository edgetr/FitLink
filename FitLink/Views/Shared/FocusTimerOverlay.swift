import SwiftUI

struct FocusTimerOverlayContent: View {
    @ObservedObject var timerManager = FocusTimerManager.shared
    @Binding var isExpanded: Bool
    
    private var cornerRadius: CGFloat {
        isExpanded ? GlassTokens.Radius.overlay : GlassTokens.Radius.pill
    }
    
    var body: some View {
        Group {
            if isExpanded {
                expandedContent
            } else {
                compactContent
            }
        }
        .modifier(LiquidGlassOverlayModifier(isExpanded: isExpanded))
    }
    
    private var expandedContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: timerManager.activeHabit?.icon ?? "clock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(timerManager.activeHabit?.name ?? "Focus")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "chevron.compact.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                    
                    Circle()
                        .trim(from: 0, to: timerManager.progress)
                        .stroke(
                            timerManager.isOnBreak ? Color.blue : Color.green,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timerManager.progress)
                    
                    VStack(spacing: 2) {
                        Text(timerManager.formattedTime)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                        
                        Text(timerManager.isOnBreak ? "BREAK" : "FOCUS")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(timerManager.isOnBreak ? .blue : .green)
                            .tracking(1)
                    }
                }
                .frame(width: 80, height: 80)
                
                VStack(spacing: 8) {
                    if timerManager.isOnBreak {
                        Button {
                            timerManager.endBreak()
                        } label: {
                            Capsule()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 84, height: 36)
                                .overlay(
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.uturn.backward")
                                            .font(.system(size: 12))
                                        Text("Resume")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundColor(.green)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            timerManager.stop()
                        } label: {
                            Capsule()
                                .fill(Color.red.opacity(0.15))
                                .frame(width: 84, height: 28)
                                .overlay(
                                    Text("Stop")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.red)
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 12) {
                            Button {
                                if timerManager.isPaused {
                                    timerManager.resume()
                                } else {
                                    timerManager.pause()
                                }
                            } label: {
                                Circle()
                                    .fill(timerManager.isPaused ? Color.green : Color.orange)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: timerManager.isPaused ? "play.fill" : "pause.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                timerManager.stop()
                            } label: {
                                Circle()
                                    .fill(Color.red.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "xmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.red)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button {
                            timerManager.startBreak()
                        } label: {
                            Capsule()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 84, height: 28)
                                .overlay(
                                    HStack(spacing: 4) {
                                        Image(systemName: "cup.and.saucer.fill")
                                            .font(.system(size: 10))
                                        Text("Break")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(.blue)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 16)
            .padding(.horizontal, 16)
        }
        .frame(width: 220)
    }
    
    private var compactContent: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                
                Circle()
                    .trim(from: 0, to: timerManager.progress)
                    .stroke(
                        timerManager.isOnBreak ? Color.blue : Color.green,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 24, height: 24)
            
            Text(timerManager.formattedTime)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .monospacedDigit()
            
            Circle()
                .fill(timerManager.isPaused ? Color.orange : (timerManager.isOnBreak ? Color.blue : Color.green))
                .frame(width: 6, height: 6)
                .padding(.leading, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 44)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isExpanded = true
            }
        }
    }
}

private struct LiquidGlassOverlayModifier: ViewModifier {
    let isExpanded: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private var cornerRadius: CGFloat {
        isExpanded ? GlassTokens.Radius.overlay : GlassTokens.Radius.pill
    }
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.8))
                        
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.12 : 0.5),
                                        Color.white.opacity(colorScheme == .dark ? 0.03 : 0.15),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.25 : 0.6),
                                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                )
        }
    }
}
