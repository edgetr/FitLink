import SwiftUI
import UIKit

struct ActivityPatternsCard: View {
    var wakeTime: String = "6:45 AM"
    var sleepTime: String = "11:15 PM"
    var stepsDelta: Double = 0.12
    var exerciseDelta: Double = -0.05
    var sleepDelta: Double = 0.0
    var activeDays: [Bool] = [false, true, false, true, false, true, false]
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        GlassCard(tint: .blue.opacity(0.3), isInteractive: true) {
            VStack(spacing: 16) {
                HStack {
                    Label {
                        Text("Your Activity Patterns")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                
                Divider().overlay(Color.primary.opacity(0.1))
                
                HStack(spacing: 0) {
                    TimeStat(icon: "sun.max.fill", title: "Wake Time", time: wakeTime, color: .orange)
                    Divider().overlay(Color.primary.opacity(0.1))
                        .padding(.vertical, 4)
                    TimeStat(icon: "moon.stars.fill", title: "Sleep Time", time: sleepTime, color: .indigo)
                }
                
                VStack(spacing: 12) {
                    Text("This Week vs Last Week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    PatternRow(title: "Steps", delta: stepsDelta, color: .green)
                    PatternRow(title: "Exercise", delta: exerciseDelta, color: .orange)
                    PatternRow(title: "Sleep", delta: sleepDelta, color: .purple)
                }
                
                VStack(spacing: 8) {
                    Text("Your Most Active Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 0) {
                        ForEach(0..<7) { index in
                            VStack(spacing: 6) {
                                Text(dayName(for: index))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                                
                                Circle()
                                    .fill(activeDays[index] ? AnyShapeStyle(Color.blue) : AnyShapeStyle(Color.primary.opacity(0.1)))
                                    .frame(width: 8, height: 8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
    }
    
    func dayName(for index: Int) -> String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return days[index]
    }
}

struct TimeStat: View {
    let icon: String
    let title: String
    let time: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(time)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PatternRow: View {
    let title: String
    let delta: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .frame(width: 70, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.5), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, geo.size.width * 0.7))
                }
            }
            .frame(height: 6)
            
            HStack(spacing: 2) {
                if abs(delta) < 0.01 {
                    Text("Same")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(Int(abs(delta * 100)))%")
                    Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                }
            }
            .font(.caption.bold())
            .foregroundStyle(deltaColor)
            .frame(width: 50, alignment: .trailing)
        }
    }
    
    var deltaColor: Color {
        if abs(delta) < 0.01 { return .secondary }
        return delta > 0 ? .green : .orange
    }
}

#Preview {
    ZStack {
        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        ActivityPatternsCard()
            .padding()
    }
}
