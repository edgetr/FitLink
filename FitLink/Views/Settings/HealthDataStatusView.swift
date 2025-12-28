import SwiftUI
import UIKit

struct HealthDataStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isSyncing: Bool = false
    @State private var lastSyncTime: Date = Date().addingTimeInterval(-120)
    
    let isConnected: Bool = true
    let daysAvailable: Int = 30
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GlassTokens.Layout.cardSpacing) {
                    
                    GlassCard(tint: isConnected ? .green : .orange) {
                        HStack(alignment: .top, spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(isConnected ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: isConnected ? "heart.text.square.fill" : "exclamationmark.triangle.fill")
                                    .font(.title2)
                                    .foregroundStyle(isConnected ? .green : .orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Health Connection")
                                    .font(.headline)
                                
                                Text(isConnected ? "Connected to HealthKit" : "Not connected")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                if isConnected {
                                    Text("Reading steps, workouts, sleep, and heart rate")
                                        .font(.caption)
                                        .foregroundStyle(.secondary.opacity(0.8))
                                        .padding(.top, 4)
                                }
                            }
                            
                            Spacer()
                            
                            if isConnected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(16)
                    }
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundStyle(.blue)
                                Text("Data Available")
                                    .font(.headline)
                            }
                            
                            Divider()
                                .overlay(Color.primary.opacity(0.1))
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(daysAvailable)")
                                        .font(.system(.title, design: .rounded).weight(.bold))
                                        .foregroundStyle(.primary)
                                    Text("Days of history")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text(lastSyncTime.formatted(date: .omitted, time: .shortened))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("Last synced")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(16)
                    }
                    
                    GlassCard {
                        VStack(spacing: 16) {
                            Text("FitLink uses your health data to generate personalized workout and diet plans.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            GlassTextPillButton(
                                isSyncing ? "Syncing..." : "Sync Now",
                                icon: isSyncing ? nil : "arrow.triangle.2.circlepath",
                                tint: .blue,
                                isProminent: true
                            ) {
                                performSync()
                            }
                            .disabled(isSyncing)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Troubleshooting")
                            .font(.headline)
                            .padding(.horizontal, 4)
                        
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                TroubleshootingRow(icon: "gear", text: "Check Health app permissions")
                                Divider().overlay(Color.primary.opacity(0.1))
                                TroubleshootingRow(icon: "lock.shield", text: "Verify privacy settings")
                                Divider().overlay(Color.primary.opacity(0.1))
                                TroubleshootingRow(icon: "wifi", text: "Ensure internet connection")
                            }
                            .padding(16)
                        }
                    }
                }
                .padding(GlassTokens.Layout.pageHorizontalPadding)
                .padding(.bottom, GlassTokens.Layout.pageBottomInset)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Health Data Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSync() {
        isSyncing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                lastSyncTime = Date()
                isSyncing = false
            }
        }
    }
}

struct TroubleshootingRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }
}

#Preview {
    HealthDataStatusView()
}
