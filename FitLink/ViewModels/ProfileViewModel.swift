import Foundation
import SwiftUI
import UIKit
import Combine

/// ViewModel for managing user profile editing, image upload, and profile settings
@MainActor
final class ProfileViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let sessionManager: SessionManager
    private let userService = UserService.shared
    
    // MARK: - Published Properties
    
    @Published var selectedImage: UIImage?
    @Published var displayName: String = ""
    @Published var isUploadingImage = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showingImagePicker = false
    @Published var showingPhotoOptions = false
    
    var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    // MARK: - Private Properties
    
    private var originalDisplayName: String = ""
    private var originalPhotoURL: String?
    private(set) var hasRemovedImage = false
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var currentProfileImageURL: URL? {
        guard let urlString = sessionManager.user?.photoURL,
              !urlString.isEmpty else {
            return nil
        }
        return URL(string: urlString)
    }
    
    var profileInitials: String {
        sessionManager.user?.initials ?? "?"
    }
    
    var hasProfileImage: Bool {
        selectedImage != nil || (currentProfileImageURL != nil && !hasRemovedImage)
    }
    
    var hasChanges: Bool {
        let nameChanged = displayName != originalDisplayName && !displayName.isEmpty
        let imageChanged = selectedImage != nil || hasRemovedImage
        return nameChanged || imageChanged
    }
    
    var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        displayName.count >= 2 &&
        displayName.count <= 50
    }
    
    var displayNameValidationMessage: String? {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "Display name is required"
        }
        if trimmed.count < 2 {
            return "Display name must be at least 2 characters"
        }
        if trimmed.count > 50 {
            return "Display name must be 50 characters or less"
        }
        return nil
    }
    
    var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    var userId: String? {
        sessionManager.currentUserID
    }
    
    // MARK: - Initialization
    
    init(sessionManager: SessionManager = .shared) {
        self.sessionManager = sessionManager
        loadUserData()
    }
    
    // MARK: - Public Methods
    
    /// Load the current user data into the form
    func loadUserData() {
        if let user = sessionManager.user {
            displayName = user.displayName
            originalDisplayName = user.displayName
            originalPhotoURL = user.photoURL
        } else if let name = sessionManager.currentUserDisplayName {
            displayName = name
            originalDisplayName = name
        }
        
        // Reset image state
        selectedImage = nil
        hasRemovedImage = false
    }
    
    /// Refresh profile data from the server
    func refreshProfile() async {
        await sessionManager.refreshUser()
        loadUserData()
    }
    
    /// Select image from camera
    func selectImageFromCamera() {
        guard isCameraAvailable else { return }
        imagePickerSourceType = .camera
        showingImagePicker = true
    }
    
    /// Select image from photo library
    func selectImageFromLibrary() {
        imagePickerSourceType = .photoLibrary
        showingImagePicker = true
    }
    
    /// Mark the profile image for removal
    func removeProfileImage() {
        selectedImage = nil
        hasRemovedImage = true
    }
    
    /// Save all profile changes
    func saveProfile() async {
        guard let userId = sessionManager.currentUserID else {
            errorMessage = "No user logged in"
            return
        }
        
        guard isFormValid else {
            errorMessage = displayNameValidationMessage
            return
        }
        
        isSaving = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName != originalDisplayName {
                try await userService.updateDisplayName(userId: userId, displayName: trimmedName)
                sessionManager.updateDisplayName(trimmedName)
            }
            
            if let newImage = selectedImage {
                isUploadingImage = true
                _ = try await userService.uploadProfileImage(newImage, for: userId)
                isUploadingImage = false
            } else if hasRemovedImage {
                try await userService.removeProfileImage(for: userId)
            }
            
            await sessionManager.refreshUser()
            
            originalDisplayName = trimmedName
            originalPhotoURL = sessionManager.user?.photoURL
            selectedImage = nil
            hasRemovedImage = false
            
            successMessage = "Profile updated successfully"
            
        } catch {
            errorMessage = error.localizedDescription
            isUploadingImage = false
        }
        
        isSaving = false
    }
    
    /// Discard any unsaved changes
    func discardChanges() {
        displayName = originalDisplayName
        selectedImage = nil
        hasRemovedImage = false
        clearMessages()
    }
    
    /// Clear error and success messages
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    /// Clear only the error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Clear only the success message
    func clearSuccess() {
        successMessage = nil
    }
    
    /// Handle image selection from picker
    func handleSelectedImage(_ image: UIImage?) {
        if let image = image {
            // Resize image if needed
            selectedImage = resizeImage(image, maxSize: CGSize(width: 500, height: 500))
            hasRemovedImage = false
        }
    }
    
    // MARK: - Private Methods
    
    private func resizeImage(_ image: UIImage, maxSize: CGSize) -> UIImage {
        let size = image.size
        
        guard size.width > maxSize.width || size.height > maxSize.height else {
            return image
        }
        
        let widthRatio = maxSize.width / size.width
        let heightRatio = maxSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
}
