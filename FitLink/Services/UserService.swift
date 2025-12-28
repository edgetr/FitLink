import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import UIKit

/// Service for user profile operations including Firestore CRUD and Firebase Storage for profile images
final class UserService {
    
    static let shared = UserService()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private init() {}
    
    // MARK: - User CRUD Operations
    
    /// Fetch a user by their ID
    /// - Parameter id: The user's Firebase UID
    /// - Returns: The User object if found
    func getUser(by id: String) async throws -> User? {
        let document = try await db.collection("users").document(id).getDocument()
        
        guard document.exists, let data = document.data() else {
            return nil
        }
        
        return User.fromDictionary(data, id: id)
    }
    
    /// Update a user's profile data
    /// - Parameter user: The User object with updated data
    func updateUser(_ user: User) async throws {
        try await db.collection("users").document(user.id).updateData(user.toDictionary())
    }
    
    /// Update only the display name for a user
    /// - Parameters:
    ///   - userId: The user's Firebase UID
    ///   - displayName: The new display name
    func updateDisplayName(userId: String, displayName: String) async throws {
        // Use setData with merge to create document if it doesn't exist
        // Also update normalized field for searchability
        try await db.collection("users").document(userId).setData([
            "display_name": displayName,
            "display_name_lowercased": displayName.lowercased()
        ], merge: true)
        
        // Also update Firebase Auth profile
        if let currentUser = Auth.auth().currentUser {
            let changeRequest = currentUser.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
        }
    }
    
    /// Update only the photo URL for a user
    /// - Parameters:
    ///   - userId: The user's Firebase UID
    ///   - photoURL: The new photo URL (or nil to remove)
    func updatePhotoURL(userId: String, photoURL: String?) async throws {
        // Use setData with merge to create document if it doesn't exist
        try await db.collection("users").document(userId).setData([
            "photo_url": photoURL as Any
        ], merge: true)
        
        // Also update Firebase Auth profile
        if let currentUser = Auth.auth().currentUser {
            let changeRequest = currentUser.createProfileChangeRequest()
            if let urlString = photoURL {
                changeRequest.photoURL = URL(string: urlString)
            } else {
                changeRequest.photoURL = nil
            }
            try await changeRequest.commitChanges()
        }
    }
    
    /// Delete a user and their associated data
    /// - Parameter userId: The user's Firebase UID
    func deleteUser(_ userId: String) async throws {
        // Delete profile image from storage if exists
        let profileImageRef = storage.reference().child("profile_images/\(userId).jpg")
        do {
            try await profileImageRef.delete()
        } catch {
            AppLogger.shared.debug("No profile image to delete or error: \(error.localizedDescription)", category: .user)
        }
        
        // Delete user document
        try await db.collection("users").document(userId).delete()
    }
    
    // MARK: - Profile Image Operations
    
    /// Upload a profile image for a user
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user's Firebase UID
    /// - Returns: The download URL for the uploaded image
    func uploadProfileImage(_ image: UIImage, for userId: String) async throws -> URL {
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw UserServiceError.imageCompressionFailed
        }
        
        // Check file size (max 5MB)
        let maxSize = 5 * 1024 * 1024 // 5MB
        if imageData.count > maxSize {
            throw UserServiceError.imageTooLarge
        }
        
        let storageRef = storage.reference().child("profile_images/\(userId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload image
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        
        // Get download URL
        let downloadURL = try await storageRef.downloadURL()
        
        // Update user document with new photo URL
        try await updatePhotoURL(userId: userId, photoURL: downloadURL.absoluteString)
        
        return downloadURL
    }
    
    /// Remove the profile image for a user
    /// - Parameter userId: The user's Firebase UID
    func removeProfileImage(for userId: String) async throws {
        let storageRef = storage.reference().child("profile_images/\(userId).jpg")
        
        do {
            try await storageRef.delete()
        } catch {
            AppLogger.shared.debug("No profile image to delete: \(error.localizedDescription)", category: .user)
        }
        
        // Update user document to remove photo URL
        try await updatePhotoURL(userId: userId, photoURL: nil)
    }
    
    /// Download a profile image from URL
    /// - Parameter urlString: The URL string of the image
    /// - Returns: The downloaded UIImage
    func downloadProfileImage(from urlString: String) async throws -> UIImage? {
        guard let url = URL(string: urlString) else {
            throw UserServiceError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
}

// MARK: - Error Types

enum UserServiceError: LocalizedError {
    case imageCompressionFailed
    case imageTooLarge
    case invalidURL
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Failed to compress image. Please try a different photo."
        case .imageTooLarge:
            return "Image is too large. Please choose a smaller photo (max 5MB)."
        case .invalidURL:
            return "Invalid image URL."
        case .userNotFound:
            return "User not found."
        }
    }
}
