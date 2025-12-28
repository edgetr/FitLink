import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DietaryProfileEditor: View {
    @Binding var profile: UserProfile
    var onSave: (UserProfile) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Namespace private var animation
    
    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    private let availableCuisines = [
        "Italian", "Mexican", "Japanese", "Chinese", 
        "Thai", "Indian", "Mediterranean", "American", 
        "French", "Greek", "Korean", "Vietnamese"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Dietary Restrictions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dietary Restrictions")
                            .font(.headline)
                            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                                GlassCard(
                                    tint: profile.dietaryRestrictions.contains(restriction) ? .green : nil,
                                    isInteractive: true
                                ) {
                                    HStack {
                                        Text(restriction.displayName)
                                            .font(.subheadline)
                                        Spacer()
                                        if profile.dietaryRestrictions.contains(restriction) {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    .padding(12)
                                }
                                .onTapGesture {
                                    toggleRestriction(restriction)
                                }
                            }
                        }
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    }
                    
                    // MARK: - Allergies
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Allergies")
                                .font(.headline)
                            Spacer()
                            if !profile.allergies.isEmpty {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        
                        GlassCard(tint: !profile.allergies.isEmpty ? .orange : nil) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Critical for meal planning")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                if #available(iOS 16.0, *) {
                                    TextField("E.g., Shellfish, Peanuts...", text: Binding(
                                        get: { profile.allergies.joined(separator: ", ") },
                                        set: { profile.allergies = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                                    ), axis: .vertical)
                                    .padding(8)
                                    .background(Color(UIColor.systemBackground).opacity(0.5))
                                    .cornerRadius(8)
                                } else {
                                    TextField("E.g., Shellfish, Peanuts...", text: Binding(
                                        get: { profile.allergies.joined(separator: ", ") },
                                        set: { profile.allergies = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                                    ))
                                    .padding(8)
                                    .background(Color(UIColor.systemBackground).opacity(0.5))
                                    .cornerRadius(8)
                                }
                            }
                            .padding()
                        }
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    }
                    
                    // MARK: - Cooking Skill Level
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cooking Skill Level")
                            .font(.headline)
                            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        
                        LiquidGlassSegmentedPicker(
                            selection: Binding(
                                get: { profile.cookingSkillLevel ?? .beginner },
                                set: { profile.cookingSkillLevel = $0 }
                            ),
                            options: CookingSkill.allCases.map { ($0, $0.displayName) },
                            namespace: animation
                        )
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    }
                    
                    // MARK: - Meal Prep Time
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preferred Meal Prep Time")
                            .font(.headline)
                            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        
                        LiquidGlassSegmentedPicker(
                            selection: Binding(
                                get: { profile.mealPrepTimePreference ?? .moderate },
                                set: { profile.mealPrepTimePreference = $0 }
                            ),
                            options: MealPrepTime.allCases.map { ($0, $0.displayName) },
                            namespace: animation
                        )
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    }
                    
                    // MARK: - Preferred Cuisines
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preferred Cuisines")
                            .font(.headline)
                            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(availableCuisines, id: \.self) { cuisine in
                                GlassCard(
                                    tint: profile.preferredCuisines.contains(cuisine) ? .orange : nil,
                                    isInteractive: true
                                ) {
                                    HStack {
                                        Text(cuisine)
                                            .font(.subheadline)
                                        Spacer()
                                        if profile.preferredCuisines.contains(cuisine) {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    .padding(12)
                                }
                                .onTapGesture {
                                    toggleCuisine(cuisine)
                                }
                            }
                        }
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    }
                    
                    // MARK: - Daily Calorie Target
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Calorie Target (Optional)")
                            .font(.headline)
                            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        
                        GlassCard {
                            HStack {
                                TextField("2000", value: $profile.dailyCalorieTarget, format: .number)
                                    .keyboardType(.numberPad)
                                Text("kcal")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    }
                    
                    Color.clear.frame(height: GlassTokens.Layout.pageBottomInset)
                }
                .padding(.vertical, 24)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Dietary Profile")
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
    
    private func toggleRestriction(_ restriction: DietaryRestriction) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if profile.dietaryRestrictions.contains(restriction) {
                profile.dietaryRestrictions.removeAll { $0 == restriction }
            } else {
                profile.dietaryRestrictions.append(restriction)
            }
        }
    }
    
    private func toggleCuisine(_ cuisine: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if profile.preferredCuisines.contains(cuisine) {
                profile.preferredCuisines.removeAll { $0 == cuisine }
            } else {
                profile.preferredCuisines.append(cuisine)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Color.gray
        .sheet(isPresented: .constant(true)) {
            DietaryProfileEditor(
                profile: .constant(UserProfile(userId: "preview")),
                onSave: { _ in }
            )
        }
}
