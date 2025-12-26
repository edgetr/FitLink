import SwiftUI

struct WorkoutsResultsView: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    @State private var selectedTab: WorkoutPlanType = .home
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented Picker (Only if both plans exist)
            if viewModel.homePlan != nil && viewModel.gymPlan != nil {
                Picker("Plan Type", selection: $selectedTab) {
                    Text("Home").tag(WorkoutPlanType.home)
                    Text("Gym").tag(WorkoutPlanType.gym)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(UIColor.systemGroupedBackground))
            }
            
            // Content
            TabView(selection: $selectedTab) {
                if let homePlan = viewModel.homePlan {
                    HomeWorkoutView(
                        plan: homePlan,
                        planType: .home,
                        selectedDayIndex: $viewModel.selectedDayIndex
                    )
                    .tag(WorkoutPlanType.home)
                }
                
                if let gymPlan = viewModel.gymPlan {
                    HomeWorkoutView(
                        plan: gymPlan,
                        planType: .gym,
                        selectedDayIndex: $viewModel.selectedDayIndex
                    )
                    .tag(WorkoutPlanType.gym)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.smooth(duration: 0.3), value: selectedTab)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button {
                        viewModel.generateShareContent(for: selectedTab)
                        viewModel.isShowingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    
                    Menu {
                        Button(role: .destructive) {
                            Task { await viewModel.deletePlan(selectedTab) }
                        } label: {
                            Label("Delete Current Plan", systemImage: "trash")
                        }
                        
                        Button {
                            viewModel.resetPlans()
                        } label: {
                            Label("Create New Plan", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            // Set initial tab based on available plans
            if viewModel.homePlan != nil && viewModel.gymPlan == nil {
                selectedTab = .home
            } else if viewModel.gymPlan != nil && viewModel.homePlan == nil {
                selectedTab = .gym
            }
        }
    }
}
