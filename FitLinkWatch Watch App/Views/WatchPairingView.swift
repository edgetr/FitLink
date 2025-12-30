import SwiftUI

#if os(watchOS)
struct WatchPairingView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @State private var enteredCode: String = ""
    @State private var waitingTimeoutSeconds: Int = 0
    @State private var waitingTimer: Timer?
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                switch sessionManager.pairingState {
                case .notPaired, .denied:
                    inputView
                case .waitingForConfirmation:
                    waitingView
                case .paired:
                    successView
                }
            }
            .animation(.easeInOut, value: sessionManager.pairingState)
        }
    }
    
    private var inputView: some View {
        VStack(spacing: 4) {
            Text(sessionManager.pairingState == .denied ? "Incorrect Code" : "Pairing Code")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(sessionManager.pairingState == .denied ? Color.red : Color.gray)
                .transition(.opacity)
                .id("header-\(sessionManager.pairingState == .denied)")
            
            HStack(spacing: 6) {
                ForEach(0..<6) { index in
                    Circle()
                        .fill(index < enteredCode.count ? Color.white : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 2)
            
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(1...9, id: \.self) { number in
                    numberButton("\(number)")
                }
                
                Color.clear.frame(height: 36)
                numberButton("0")
                deleteButton
            }
            .padding(.horizontal, 2)
        }
        .padding(.top, 2)
    }
    
    private var waitingView: some View {
        VStack(spacing: 12) {
            if waitingTimeoutSeconds < 10 {
                ProgressView()
                    .tint(.accentColor)
                    .scaleEffect(1.5)
                
                Text("Verifying...")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow)
                
                Text("No Response")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(.gray)
                
                Button {
                    retryPairing()
                } label: {
                    Text("Retry")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .transition(.opacity)
        .onAppear { startWaitingTimer() }
        .onDisappear { stopWaitingTimer() }
    }
    
    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.green)
                .symbolEffect(.bounce)
            
            Text("Paired")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    private func numberButton(_ number: String) -> some View {
        Button {
            handleInput(number)
        } label: {
            Text(number)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .frame(width: 36, height: 36)
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private var deleteButton: some View {
        Button {
            handleDelete()
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .foregroundColor(enteredCode.isEmpty ? .gray.opacity(0.3) : .red.opacity(0.8))
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(enteredCode.isEmpty)
    }
    
    private func handleInput(_ number: String) {
        if sessionManager.pairingState == .denied {
            sessionManager.resetPairingState()
            enteredCode = ""
        }
        
        guard enteredCode.count < 6 else { return }
        enteredCode.append(number)
        
        if enteredCode.count == 6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                sessionManager.submitPairingCode(enteredCode)
            }
        }
    }
    
    private func handleDelete() {
        if sessionManager.pairingState == .denied {
            sessionManager.resetPairingState()
            enteredCode = ""
            return
        }
        
        guard !enteredCode.isEmpty else { return }
        enteredCode.removeLast()
    }
    
    private func startWaitingTimer() {
        waitingTimeoutSeconds = 0
        waitingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            waitingTimeoutSeconds += 1
        }
    }
    
    private func stopWaitingTimer() {
        waitingTimer?.invalidate()
        waitingTimer = nil
    }
    
    private func retryPairing() {
        stopWaitingTimer()
        sessionManager.submitPairingCode(enteredCode)
        startWaitingTimer()
    }
}

#if DEBUG
struct WatchPairingView_Previews: PreviewProvider {
    static var previews: some View {
        WatchPairingView()
            .environmentObject(WatchSessionManager.shared)
    }
}
#endif
#endif
