import SwiftUI
import UIKit

struct ProfileCompletenessIndicator: View {
    let completeness: Double
    let showMessage: Bool
    
    @State private var animatedCompleteness: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    
    private var percentage: Int {
        Int(completeness * 100)
    }
    
    private var message: String {
        if completeness < 0.5 {
            return "Let's get started!"
        } else if completeness < 0.8 {
            return "Good progress!"
        } else {
            return "Almost complete!"
        }
    }
    
    private var gradientColors: [Color] {
        if completeness >= 1.0 {
            return [.green, .mint]
        }
        return [.blue, .purple]
    }
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label {
                        Text("Profile Completeness")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "person.text.rectangle")
                            .foregroundStyle(.blue)
                    }
                    
                    Spacer()
                    
                    Text("\(percentage)%")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * animatedCompleteness, height: 8)
                            .shadow(color: gradientColors.last?.opacity(0.5) ?? .clear, radius: 4, x: 0, y: 0)
                    }
                }
                .frame(height: 8)
                
                if showMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                if completeness < 0.5 {
                    Text("More data = better personalization")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            .padding(16)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedCompleteness = completeness
            }
        }
        .onChange(of: completeness) { newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedCompleteness = newValue
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        
        VStack(spacing: 20) {
            ProfileCompletenessIndicator(completeness: 0.3, showMessage: true)
            ProfileCompletenessIndicator(completeness: 0.72, showMessage: true)
            ProfileCompletenessIndicator(completeness: 0.95, showMessage: true)
        }
        .padding()
    }
}
