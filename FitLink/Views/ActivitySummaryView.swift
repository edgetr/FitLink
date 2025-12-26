import SwiftUI

struct ActivitySummaryView: View {
    @ObservedObject var viewModel: ActivitySummaryViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Today's Activity")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if viewModel.showAuthorizationWarning {
                    authorizationWarningBanner
                }
                
                statsCardsRow
                
                moreDetailsSection
                
                Spacer()
            }
            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
            .padding(.top, 16)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Activity Summary")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            viewModel.refreshData()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
    }
    
    private var authorizationWarningBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("HealthKit Access Required")
                        .font(.headline)
                    
                    Text(authorizationMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button {
                    viewModel.openAppSettings()
                } label: {
                    Text("Open Settings")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                
                if viewModel.isHealthKitAvailable {
                    Button {
                        viewModel.requestAuthorization()
                    } label: {
                        Text("Try Again")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card))
    }
    
    private var authorizationMessage: String {
        switch viewModel.authorizationStatus {
        case .denied:
            return "Please enable HealthKit access in Settings to see your real activity data."
        case .unavailable:
            return "HealthKit is not available on this device. Showing sample data."
        default:
            return "Grant access to see your steps and calories."
        }
    }
    
    private var statsCardsRow: some View {
        HStack(spacing: 16) {
            ActivityStatCard(
                icon: "figure.walk",
                iconColor: .orange,
                value: viewModel.formattedSteps,
                label: "Steps"
            )
            
            ActivityStatCard(
                icon: "flame.fill",
                iconColor: .red,
                value: "\(viewModel.formattedCalories) Cal",
                label: "Active Energy"
            )
        }
    }
    
    private var moreDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("More Details")
                .font(.headline)
            
            VStack(spacing: 0) {
                DetailRow(
                    icon: "figure.run",
                    iconColor: .green,
                    label: "Exercise Minutes",
                    value: viewModel.formattedExerciseMinutes
                )
                
                Divider()
                    .padding(.leading, 36)
                
                DetailRow(
                    icon: "heart.fill",
                    iconColor: .pink,
                    label: "Heart Rate",
                    value: "N/A"
                )
                
                Divider()
                    .padding(.leading, 36)
                
                DetailRow(
                    icon: "moon.fill",
                    iconColor: .indigo,
                    label: "Sleep",
                    value: "N/A"
                )
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActivityStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(iconColor)
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.semibold)
                .monospacedDigit()
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card))
    }
}

struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    
    init(icon: String, iconColor: Color = .secondary, label: String, value: String) {
        self.icon = icon
        self.iconColor = iconColor
        self.label = label
        self.value = value
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            Text(label)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
    }
}

#Preview("Authorized") {
    NavigationStack {
        ActivitySummaryView(viewModel: ActivitySummaryViewModel())
    }
}
