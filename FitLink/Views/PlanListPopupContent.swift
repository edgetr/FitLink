import SwiftUI

struct PlanListPopupContent: View {
    @ObservedObject var viewModel: DietPlannerViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.activeDietPlans.isEmpty && viewModel.archivedDietPlans.isEmpty {
                        emptyState
                    } else {
                        if !viewModel.activeDietPlans.isEmpty {
                            sectionHeader("Active Plans")
                            
                            ForEach(viewModel.activeDietPlans) { plan in
                                PlanRow(plan: plan, isSelected: viewModel.currentDietPlan?.id == plan.id) {
                                    viewModel.selectPlan(plan)
                                    dismiss()
                                } onDelete: {
                                    Task {
                                        await viewModel.deletePlan(plan)
                                    }
                                }
                            }
                        }
                        
                        if !viewModel.archivedDietPlans.isEmpty {
                            sectionHeader("Archived Plans")
                            
                            ForEach(viewModel.archivedDietPlans) { plan in
                                PlanRow(plan: plan, isSelected: false) {
                                    viewModel.selectPlan(plan)
                                    dismiss()
                                } onDelete: {
                                    Task {
                                        await viewModel.deletePlan(plan)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Your Diet Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No diet plans found")
                .font(.headline)
            
            Text("Generate a new plan to get started!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
}

private struct PlanRow: View {
    let plan: DietPlan
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        GlassCard(tint: isSelected ? .blue.opacity(0.1) : nil, isInteractive: true) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        
                        Text(plan.formattedWeekRange)
                            .font(.headline)
                    }
                    
                    if !plan.preferences.isEmpty {
                        Text(plan.preferences)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text("\(plan.summary.avgCaloriesPerDay) kcal/day")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
            .padding()
        }
        .onTapGesture {
            onSelect()
        }
    }
}
