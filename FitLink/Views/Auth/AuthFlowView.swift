import SwiftUI
import UIKit

enum AuthTab: String, CaseIterable {
    case signIn = "Sign In"
    case signUp = "Sign Up"
}

struct AuthFlowView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var selectedTab: AuthTab = .signIn
    @Namespace private var authNamespace
    @FocusState private var focusedField: AuthField?
    
    enum AuthField: Hashable {
        case displayName, email, password, confirmPassword, resetEmail
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: geometry.size.height < 700 ? 16 : 24) {
                Spacer(minLength: 0)
                
                appHeader(compact: geometry.size.height < 750)
                tabPicker
                
                ZStack(alignment: .top) {
                    SignInFormView(
                        viewModel: viewModel,
                        focusedField: $focusedField,
                        compact: geometry.size.height < 700
                    )
                    .opacity(selectedTab == .signIn ? 1 : 0)
                    
                    SignUpFormView(
                        viewModel: viewModel,
                        focusedField: $focusedField,
                        compact: geometry.size.height < 750
                    )
                    .opacity(selectedTab == .signUp ? 1 : 0)
                }
                .animation(.smooth(duration: 0.25), value: selectedTab)
                
                legalLinks
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
            .onTapGesture {
                focusedField = nil
            }
            .sheet(isPresented: $viewModel.showResetPasswordSheet) {
                ResetPasswordSheet(viewModel: viewModel)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: selectedTab) { _, _ in
                viewModel.clearMessages()
                focusedField = nil
            }
        }
    }
    
    private func appHeader(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: compact ? 44 : 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("FitLink")
                .font(compact ? .title : .largeTitle)
                .fontWeight(.bold)
            
            if !compact {
                Text("Your fitness journey, connected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, compact ? 4 : 8)
    }
    
    private var tabPicker: some View {
        GlassEffectContainer(spacing: 4) {
            ForEach(AuthTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.headline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .glassEffect(selectedTab == tab ? .regular.interactive() : .clear)
                .glassEffectID(tab, in: authNamespace)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
    
    private var legalLinks: some View {
        VStack(spacing: 8) {
            Text("By continuing, you agree to our")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 4) {
                Button("Privacy Policy") {
                    if let url = URL(string: "https://fitlink.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
                .foregroundStyle(.blue)
                
                Text("and")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Terms of Service") {
                    if let url = URL(string: "https://fitlink.app/terms") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
        .padding(.top, 16)
    }
}

struct SignInFormView: View {
    @ObservedObject var viewModel: AuthViewModel
    var focusedField: FocusState<AuthFlowView.AuthField?>.Binding
    var compact: Bool = false
    
    var body: some View {
        VStack(spacing: compact ? 12 : 20) {
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.clearMessages()
                }
            }
            
            VStack(spacing: compact ? 10 : 16) {
                VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                    Text("Email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("you@example.com", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused(focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField.wrappedValue = .password }
                    
                    if let message = viewModel.emailValidationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                    Text("Password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    SecureField("Enter password", text: $viewModel.password)
                        .textContentType(.password)
                        .focused(focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit {
                            if viewModel.canSignIn {
                                Task { await viewModel.signIn() }
                            }
                        }
                }
            }
            .padding(compact ? 12 : 16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
            
            HStack {
                Spacer()
                Button("Forgot Password?") {
                    viewModel.showResetPasswordSheet = true
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
            
            Button {
                focusedField.wrappedValue = nil
                Task { await viewModel.signIn() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text("Sign In")
                }
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .controlSize(.large)
            .disabled(!viewModel.canSignIn || viewModel.isLoading)
        }
    }
}

struct SignUpFormView: View {
    @ObservedObject var viewModel: AuthViewModel
    var focusedField: FocusState<AuthFlowView.AuthField?>.Binding
    var compact: Bool = false
    
    var body: some View {
        VStack(spacing: compact ? 12 : 20) {
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.clearMessages()
                }
            }
            
            VStack(spacing: compact ? 8 : 16) {
                VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                    Text("Display Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("John Doe", text: $viewModel.displayName)
                        .textContentType(.name)
                        .focused(focusedField, equals: .displayName)
                        .submitLabel(.next)
                        .onSubmit { focusedField.wrappedValue = .email }
                    
                    if let message = viewModel.displayNameValidationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                    Text("Email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("you@example.com", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused(focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField.wrappedValue = .password }
                    
                    if let message = viewModel.emailValidationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                    Text("Password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    SecureField("Minimum 8 characters", text: $viewModel.password)
                        .textContentType(.newPassword)
                        .focused(focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focusedField.wrappedValue = .confirmPassword }
                    
                    if !viewModel.password.isEmpty {
                        PasswordStrengthIndicator(strength: viewModel.passwordStrength)
                    }
                    
                    if let message = viewModel.passwordValidationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                    Text("Confirm Password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    SecureField("Re-enter password", text: $viewModel.confirmPassword)
                        .textContentType(.newPassword)
                        .focused(focusedField, equals: .confirmPassword)
                        .submitLabel(.go)
                        .onSubmit {
                            if viewModel.canSignUp {
                                Task { await viewModel.signUp() }
                            }
                        }
                    
                    if let message = viewModel.confirmPasswordValidationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(compact ? 12 : 16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
            
            Button {
                focusedField.wrappedValue = nil
                Task { await viewModel.signUp() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text("Create Account")
                }
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .controlSize(.large)
            .disabled(!viewModel.canSignUp || viewModel.isLoading)
        }
    }
}

struct PasswordStrengthIndicator: View {
    let strength: PasswordStrength
    
    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(UIColor.tertiarySystemFill))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(strength.color)
                        .frame(width: geometry.size.width * strength.progress)
                        .animation(.smooth(duration: 0.3), value: strength)
                }
            }
            .frame(height: 4)
            
            Text(strength.rawValue)
                .font(.caption2)
                .foregroundStyle(strength.color)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.top, 4)
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card))
    }
}

struct ResetPasswordSheet: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEmailFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                    
                    Text("Reset Password")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your email and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                if let success = viewModel.successMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        
                        Text(success)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card))
                }
                
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.clearMessages()
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("you@example.com", text: $viewModel.resetEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isEmailFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            if viewModel.canResetPassword {
                                Task { await viewModel.resetPassword() }
                            }
                        }
                }
                .padding(16)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
                
                Button {
                    isEmailFocused = false
                    Task { await viewModel.resetPassword() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Send Reset Link")
                    }
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .controlSize(.large)
                .disabled(!viewModel.canResetPassword || viewModel.isLoading)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        viewModel.resetEmail = ""
                        viewModel.clearMessages()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isEmailFocused = true
        }
    }
}

#Preview("Auth Flow") {
    AuthFlowView()
}
