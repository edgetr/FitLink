import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FitnessProfileEditor: View {
    @Binding var profile: UserProfile
    var onSave: (UserProfile) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Namespace private var animation
    
    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Fitness Level
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Fitness Level")
                            .font(.headline)
                            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        
                        LiquidGlassSegmentedPicker(
                            selection: Binding(
                                get: { profile.fitnessLevel ?? .beginner },
                                set: { profile.fitnessLevel = $0 }
                            ),
                            options: FitnessLevel.allCases.map { ($0, $0.displayName) },
                            namespace: animation
                        )
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    }
                    
                    // MARK: - Primary Goals
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Primary Goals")
                            .font(.headline)
                            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        
                        Text("Select up to 3")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                            .padding(.top, -8)
                        
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(FitnessGoal.allCases, id: \.self) { goal in
                                GlassCard(
                                    tint: profile.primaryGoals.contains(goal) ? .blue : nil,
                                    isInteractive: true
                                ) {
                                    HStack {
                                        Text(emoji(for: goal))
                                        Text(goal.displayName)
                                            .font(.subheadline)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        if profile.primaryGoals.contains(goal) {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .padding(12)
                                }
                                .onTapGesture {
                                    toggleGoal(goal)
                                }
                            }
                        }
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    }
                    
                    // MARK: - Preferred Workout Times
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preferred Workout Times")
                            .font(.headline)
                            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(TimeOfDay.allCases, id: \.self) { time in
                                GlassCard(
                                    tint: profile.preferredWorkoutTimes.contains(time) ? .purple : nil,
                                    isInteractive: true
                                ) {
                                    HStack {
                                        Text(time.displayName)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                        Spacer()
                                        if profile.preferredWorkoutTimes.contains(time) {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .foregroundStyle(.purple)
                                        }
                                    }
                                    .padding(12)
                                }
                                .onTapGesture {
                                    toggleTime(time)
                                }
                            }
                        }
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    }
                    
                    // MARK: - Equipment Available
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Equipment Available")
                            .font(.headline)
                            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(Equipment.allCases, id: \.self) { item in
                                GlassCard(
                                    tint: profile.availableEquipment.contains(item) ? .indigo : nil,
                                    isInteractive: true
                                ) {
                                    HStack {
                                        Text(item.displayName)
                                            .font(.subheadline)
                                        Spacer()
                                        if profile.availableEquipment.contains(item) {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .foregroundStyle(.indigo)
                                        }
                                    }
                                    .padding(12)
                                }
                                .onTapGesture {
                                    toggleEquipment(item)
                                }
                            }
                        }
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    }
                    
                    // MARK: - Injuries or Limitations
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Injuries or Limitations")
                            .font(.headline)
                            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        
                        GlassCard {
                            VStack(alignment: .leading) {
                                if #available(iOS 16.0, *) {
                                    TextField("E.g., Lower back sensitivity, knee pain...", text: Binding(
                                        get: { profile.injuriesOrLimitations.joined(separator: ", ") },
                                        set: { profile.injuriesOrLimitations = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                                    ), axis: .vertical)
                                    .lineLimit(3...6)
                                    .padding()
                                } else {
                                    TextField("E.g., Lower back sensitivity...", text: Binding(
                                        get: { profile.injuriesOrLimitations.joined(separator: ", ") },
                                        set: { profile.injuriesOrLimitations = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                                    ))
                                    .padding()
                                }
                            }
                        }
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    }
                    
                    Color.clear.frame(height: GlassTokens.Layout.pageBottomInset)
                }
                .padding(.vertical, 24)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Fitness Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(profile)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func toggleGoal(_ goal: FitnessGoal) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if profile.primaryGoals.contains(goal) {
                profile.primaryGoals.removeAll { $0 == goal }
            } else {
                if profile.primaryGoals.count < 3 {
                    profile.primaryGoals.append(goal)
                }
            }
        }
    }
    
    private func toggleTime(_ time: TimeOfDay) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if profile.preferredWorkoutTimes.contains(time) {
                profile.preferredWorkoutTimes.removeAll { $0 == time }
            } else {
                profile.preferredWorkoutTimes.append(time)
            }
        }
    }
    
    private func toggleEquipment(_ item: Equipment) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if profile.availableEquipment.contains(item) {
                profile.availableEquipment.removeAll { $0 == item }
            } else {
                profile.availableEquipment.append(item)
            }
        }
    }
    
    private func emoji(for goal: FitnessGoal) -> String {
        switch goal {
        case .loseWeight: return "🔥"
        case .buildMuscle: return "💪"
        case .improveEndurance: return "🏃"
        case .maintainFitness: return "⚖️"
        case .increaseFlexibility: return "🧘"
        case .reduceStress: return "😌"
        case .improveHealth: return "❤️"
        case .trainForEvent: return "🏆"
        }
    }
}

// MARK: - Preview

#Preview {
    Color.gray
        .sheet(isPresented: .constant(true)) {
            FitnessProfileEditor(
                profile: .constant(UserProfile(userId: "preview")),
                onSave: { _ in }
            )
        }
}
