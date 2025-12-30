import SwiftUI

#if os(iOS)
struct WatchPairingView: View {
    @StateObject private var pairingService = WatchPairingService.shared
    @ObservedObject private var connectivityService = WatchConnectivityService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showUnpairConfirmation = false
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: GlassTokens.Padding.hero) {
                    if pairingService.isPaired {
                        pairedContentView
                    } else {
                        pairingContentView
                    }
                }
                .padding(.bottom, GlassTokens.Layout.pageBottomInset)
            }
            
            if pairingService.pendingPairingRequest {
                pairingConfirmationOverlay
            }
        }
        .onAppear {
            if !pairingService.isPaired {
                pairingService.startPairingSession()
            }
        }
        .onDisappear {
            pairingService.endPairingSession()
        }
        .navigationTitle(pairingService.isPaired ? "My Watch" : "Pair Apple Watch")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Unpair Apple Watch?",
            isPresented: $showUnpairConfirmation,
            titleVisibility: .visible
        ) {
            Button("Unpair", role: .destructive) {
                pairingService.unpair()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your Apple Watch will no longer sync with FitLink. You can pair again at any time.")
        }
    }
    
    // MARK: - Paired Content
    
    private var pairedContentView: some View {
        VStack(spacing: GlassTokens.Padding.section) {
            VStack(spacing: GlassTokens.Padding.small) {
                Image(systemName: "applewatch.watchface")
                    .font(.system(size: GlassTokens.IconSize.hero))
                    .foregroundStyle(.linearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(.bottom, GlassTokens.Padding.standard)
                
                Text("Apple Watch")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(connectivityService.isWatchReachable ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(connectivityService.isWatchReachable ? "Connected" : "Not Reachable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, GlassTokens.Padding.large)
            
            watchInfoCard
            
            Spacer(minLength: GlassTokens.Padding.section)
            
            Button {
                showUnpairConfirmation = true
            } label: {
                Text("Unpair Apple Watch")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background {
                        Capsule()
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    }
            }
            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
        }
    }
    
    private var watchInfoCard: some View {
        VStack(spacing: 0) {
            watchInfoRow(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "Paired",
                value: "Yes"
            )
            
            Divider()
                .padding(.leading, 48)
            
            watchInfoRow(
                icon: "app.badge.checkmark.fill",
                iconColor: .blue,
                title: "Watch App",
                value: connectivityService.isWatchAppInstalled ? "Installed" : "Not Installed"
            )
            
            Divider()
                .padding(.leading, 48)
            
            watchInfoRow(
                icon: "antenna.radiowaves.left.and.right",
                iconColor: connectivityService.isWatchReachable ? .green : .orange,
                title: "Status",
                value: connectivityService.isWatchReachable ? "Reachable" : "Not Reachable"
            )
        }
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: GlassTokens.Radius.card)
                    .fill(.regularMaterial)
                    .glassEffect(.regular)
            } else {
                RoundedRectangle(cornerRadius: GlassTokens.Radius.card)
                    .fill(Color.primary.opacity(0.05))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card))
        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
    }
    
    private func watchInfoRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: GlassTokens.Padding.standard) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 28)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, GlassTokens.Padding.standard)
        .padding(.vertical, 14)
    }
    
    // MARK: - Pairing Content
    
    private var pairingContentView: some View {
        VStack(spacing: GlassTokens.Padding.hero) {
            VStack(spacing: GlassTokens.Padding.small) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: GlassTokens.IconSize.hero))
                    .foregroundStyle(.linearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                    .padding(.bottom, GlassTokens.Padding.standard)
                
                Text("Pair Apple Watch")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                
                Text("Enter this code on your Apple Watch to securely link your devices.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
            }
            .padding(.top, GlassTokens.Padding.large)
            
            VStack(spacing: GlassTokens.Padding.large) {
                HStack(spacing: GlassTokens.Padding.small) {
                    ForEach(Array(pairingService.currentCode.enumerated()), id: \.offset) { _, char in
                        CodeDigitView(digit: String(char))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: pairingService.currentCode)
                
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(pairingService.secondsRemaining) / 60.0)
                        .stroke(
                            AngularGradient(
                                colors: [.blue, .cyan, .purple, .blue],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: pairingService.secondsRemaining)
                    
                    VStack(spacing: 2) {
                        Text("\(pairingService.secondsRemaining)")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        
                        Text("SEC")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)
                .padding(.top, GlassTokens.Padding.standard)
            }
            .transition(.opacity)
        }
    }
    
    // MARK: - Pairing Confirmation Overlay
    
    private var pairingConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .transition(.opacity)
            
            VStack(spacing: GlassTokens.Padding.section) {
                VStack(spacing: GlassTokens.Padding.standard) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: GlassTokens.IconSize.large))
                        .foregroundStyle(Color.blue.gradient)
                    
                    Text("Pairing Request")
                        .font(.title3.weight(.bold))
                    
                    Text("Verify the code matches the one displayed on your Apple Watch.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(pairingService.currentCode)
                        .font(.system(.title, design: .monospaced).weight(.bold))
                        .padding(.vertical, GlassTokens.Padding.small)
                        .padding(.horizontal, GlassTokens.Padding.standard)
                        .background {
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                        }
                }
                
                HStack(spacing: GlassTokens.Padding.standard) {
                    Button {
                        withAnimation {
                            pairingService.denyPairing()
                        }
                    } label: {
                        Text("Deny")
                            .font(.headline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Button {
                        withAnimation {
                            pairingService.confirmPairing()
                        }
                    } label: {
                        Text("Allow")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.blue.gradient))
                    }
                }
            }
            .padding(GlassTokens.Padding.section)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: GlassTokens.Radius.overlay)
                        .fill(.regularMaterial)
                        .glassEffect(.regular)
                } else {
                    RoundedRectangle(cornerRadius: GlassTokens.Radius.overlay)
                        .fill(.regularMaterial)
                }
            }
            .padding(GlassTokens.Layout.pageHorizontalPadding)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
            .zIndex(100)
        }
    }
}

private struct CodeDigitView: View {
    let digit: String
    
    var body: some View {
        Text(digit)
            .font(.system(size: 32, weight: .bold, design: .monospaced))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 64)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: GlassTokens.Radius.small)
                        .fill(Color.primary.opacity(0.05))
                        .glassEffect(.regular)
                } else {
                    RoundedRectangle(cornerRadius: GlassTokens.Radius.small)
                        .fill(Color.primary.opacity(0.05))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: GlassTokens.Radius.small)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            }
    }
}

#Preview {
    NavigationView {
        WatchPairingView()
    }
}
#endif
