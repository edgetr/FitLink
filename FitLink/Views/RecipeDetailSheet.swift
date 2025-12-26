import SwiftUI

struct RecipeDetailSheet: View {
    let recipe: Recipe
    let nutrition: NutritionInfo
    @State private var checkedIngredients: Set<String> = []
    @Environment(\.dismiss) var dismiss
    @State private var isSharing = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Image
                    if let imageUrl = recipe.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(ProgressView())
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "fork.knife.circle")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.secondary)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(height: 250)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(LinearGradient(colors: [.orange.opacity(0.3), .red.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "fork.knife.circle")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.white.opacity(0.8))
                            )
                    }
                    
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Text(recipe.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 16) {
                                Label(recipe.formattedPrepTime, systemImage: "clock")
                                Label("\(recipe.servings) serv", systemImage: "person.2")
                                Label(recipe.difficulty.displayName, systemImage: recipe.difficulty.icon)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        
                        // Nutrition Summary
                        GlassCard {
                            VStack(spacing: 12) {
                                Text("Nutrition Per Serving")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                HStack(spacing: 20) {
                                    MacroView(label: "Calories", value: "\(nutrition.calories)", unit: "", color: .gray)
                                    MacroView(label: "Protein", value: "\(nutrition.protein)", unit: "g", color: .red)
                                    MacroView(label: "Carbs", value: "\(nutrition.carbs)", unit: "g", color: .blue)
                                    MacroView(label: "Fats", value: "\(nutrition.fat)", unit: "g", color: .yellow)
                                }
                            }
                            .padding()
                        }
                        
                        // Explanation
                        if !recipe.explanation.isEmpty {
                            Text(recipe.explanation)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Ingredients
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Ingredients")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            VStack(spacing: 12) {
                                ForEach(recipe.ingredients) { ingredient in
                                    HStack {
                                        Button {
                                            toggleIngredient(ingredient.name)
                                        } label: {
                                            Image(systemName: checkedIngredients.contains(ingredient.name) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(checkedIngredients.contains(ingredient.name) ? .green : .secondary)
                                        }
                                        
                                        Text(ingredient.amount)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.secondary)
                                        
                                        Text(ingredient.name)
                                            .strikethrough(checkedIngredients.contains(ingredient.name))
                                            .foregroundStyle(checkedIngredients.contains(ingredient.name) ? .secondary : .primary)
                                        
                                        Spacer()
                                        
                                        Text(ingredient.category.icon)
                                    }
                                    .padding(.vertical, 4)
                                    Divider()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Instructions")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            VStack(alignment: .leading, spacing: 20) {
                                ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top, spacing: 16) {
                                        Text("\(index + 1)")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .frame(width: 28, height: 28)
                                            .background(Circle().fill(Color.blue))
                                        
                                        Text(step)
                                            .font(.body)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Tips
                        if !recipe.cookingTips.isEmpty {
                            GlassCard(tint: .yellow.opacity(0.1)) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Chef's Tips", systemImage: "lightbulb.fill")
                                        .font(.headline)
                                        .foregroundStyle(.orange)
                                    
                                    ForEach(recipe.cookingTips, id: \.self) { tip in
                                        Text("• " + tip)
                                            .font(.subheadline)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        // Mistakes
                        if !recipe.commonMistakes.isEmpty {
                            GlassCard(tint: .red.opacity(0.1)) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Common Mistakes", systemImage: "exclamationmark.triangle.fill")
                                        .font(.headline)
                                        .foregroundStyle(.red)
                                    
                                    ForEach(recipe.commonMistakes, id: \.self) { mistake in
                                        Text("• " + mistake)
                                            .font(.subheadline)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        // Bottom Actions
                        GlassTextPillButton("Share Recipe", icon: "square.and.arrow.up") {
                            shareItems = [recipe.formattedForSharing()]
                            isSharing = true
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                    .padding(24)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(UIColor.systemGroupedBackground))
            .sheet(isPresented: $isSharing) {
                ShareSheet(items: shareItems)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title2)
                    }
                }
            }
        }
    }
    
    private func toggleIngredient(_ name: String) {
        if checkedIngredients.contains(name) {
            checkedIngredients.remove(name)
        } else {
            checkedIngredients.insert(name)
        }
    }
}

private struct MacroView: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
