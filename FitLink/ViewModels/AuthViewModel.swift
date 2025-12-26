import Foundation
import SwiftUI
import Combine

enum PasswordStrength: String {
    case none = "None"
    case weak = "Weak"
    case medium = "Medium"
    case strong = "Strong"
    
    var color: Color {
        switch self {
        case .none: .gray
        case .weak: .red
        case .medium: .orange
        case .strong: .green
        }
    }
    
    var progress: Double {
        switch self {
        case .none: 0.0
        case .weak: 0.33
        case .medium: 0.66
        case .strong: 1.0
        }
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""
    @Published var resetEmail = ""
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showResetPasswordSheet = false
    
    private let sessionManager: SessionManager
    
    init(sessionManager: SessionManager? = nil) {
        self.sessionManager = sessionManager ?? SessionManager.shared
    }
    
    private static let emailPattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
    
    var isEmailValid: Bool {
        guard !email.isEmpty else { return false }
        return email.range(of: Self.emailPattern, options: .regularExpression) != nil
    }
    
    var emailValidationMessage: String? {
        guard !email.isEmpty else { return nil }
        return isEmailValid ? nil : "Please enter a valid email address"
    }
    
    var isPasswordValid: Bool {
        password.count >= 8
    }
    
    var passwordValidationMessage: String? {
        guard !password.isEmpty else { return nil }
        if password.count < 8 {
            return "Password must be at least 8 characters"
        }
        return nil
    }
    
    var passwordStrength: PasswordStrength {
        guard !password.isEmpty else { return .none }
        
        var score = 0
        
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        
        let hasUppercase = password.contains(where: { $0.isUppercase })
        let hasLowercase = password.contains(where: { $0.isLowercase })
        let hasDigit = password.contains(where: { $0.isNumber })
        let hasSpecial = password.contains(where: { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) })
        
        if hasUppercase { score += 1 }
        if hasLowercase { score += 1 }
        if hasDigit { score += 1 }
        if hasSpecial { score += 1 }
        
        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        default: return .strong
        }
    }
    
    var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }
    
    var confirmPasswordValidationMessage: String? {
        guard !confirmPassword.isEmpty else { return nil }
        return passwordsMatch ? nil : "Passwords do not match"
    }
    
    var isDisplayNameValid: Bool {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }
    
    var displayNameValidationMessage: String? {
        guard !displayName.isEmpty else { return nil }
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            return "Name must be at least 2 characters"
        }
        return nil
    }
    
    var canSignIn: Bool {
        isEmailValid && isPasswordValid
    }
    
    var canSignUp: Bool {
        isDisplayNameValid && isEmailValid && isPasswordValid && passwordsMatch
    }
    
    var canResetPassword: Bool {
        let trimmedEmail = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return false }
        return trimmedEmail.range(of: Self.emailPattern, options: .regularExpression) != nil
    }
    
    func signIn() async {
        guard canSignIn else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await sessionManager.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        } catch {
            errorMessage = sessionManager.errorMessage ?? "Sign in failed. Please try again."
        }
        
        isLoading = false
    }
    
    func signUp() async {
        guard canSignUp else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await sessionManager.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            errorMessage = sessionManager.errorMessage ?? "Sign up failed. Please try again."
        }
        
        isLoading = false
    }
    
    func resetPassword() async {
        guard canResetPassword else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await sessionManager.resetPassword(email: resetEmail.trimmingCharacters(in: .whitespacesAndNewlines))
            successMessage = "Password reset email sent. Check your inbox."
            resetEmail = ""
            
            try? await Task.sleep(for: .seconds(2))
            showResetPasswordSheet = false
        } catch {
            errorMessage = sessionManager.errorMessage ?? "Failed to send reset email. Please try again."
        }
        
        isLoading = false
    }
    
    func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
        resetEmail = ""
        errorMessage = nil
        successMessage = nil
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
