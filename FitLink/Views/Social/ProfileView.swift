import SwiftUI
import UIKit

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @EnvironmentObject var sessionManager: SessionManager
    
    init() {
        self._viewModel = StateObject(wrappedValue: ProfileViewModel())
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // 1. Profile Header Section
                    profileHeaderSection
                    
                    // 2. Display Name Section
                    displayNameSection
                    
                    // 3. Action Buttons Section
                    actionButtonsSection
                }
                .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                .padding(.vertical, 24)
            }
            
            // Status Messages (Overlay)
            statusMessageOverlay
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .onAppear {
            viewModel.loadUserData()
        }
        // Confirmation Dialog for Photo Options
        .confirmationDialog("Change Photo", isPresented: $viewModel.showingPhotoOptions, titleVisibility: .visible) {
            if viewModel.isCameraAvailable {
                Button("Take Photo") {
                    viewModel.selectImageFromCamera()
                }
            }
            
            Button("Choose from Library") {
                viewModel.selectImageFromLibrary()
            }
            
            if viewModel.hasProfileImage {
                Button("Remove Photo", role: .destructive) {
                    viewModel.removeProfileImage()
                }
            }
            
            Button("Cancel", role: .cancel) { }
        }
        // Image Picker Sheet
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePicker(
                sourceType: viewModel.imagePickerSourceType,
                selectedImage: { image in
                    viewModel.handleSelectedImage(image)
                }
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Subviews
    
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Avatar
            ProfileAvatarView(
                selectedImage: viewModel.selectedImage,
                imageURL: viewModel.currentProfileImageURL,
                initials: viewModel.profileInitials,
                hasRemovedImage: viewModel.hasRemovedImage,
                size: 120
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            // Change Photo Button
            Button {
                viewModel.showingPhotoOptions = true
            } label: {
                Text("Change Photo")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var displayNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Name")
                .font(.headline)
                .foregroundStyle(.primary)
            
            TextField("Enter display name", text: $viewModel.displayName)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: GlassTokens.Radius.small)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )
            
            if let validationMessage = viewModel.displayNameValidationMessage, !viewModel.displayName.isEmpty {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: GlassTokens.Radius.card)
                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
        )
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Save Button
            Button {
                Task {
                    await viewModel.saveProfile()
                }
            } label: {
                HStack {
                    if viewModel.isSaving || viewModel.isUploadingImage {
                        ProgressView()
                            .tint(.white)
                            .padding(.trailing, 8)
                    }
                    
                    Text(viewModel.isSaving ? "Saving..." : "Save Changes")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    (viewModel.hasChanges && viewModel.isFormValid && !viewModel.isSaving) ?
                    Color.blue.gradient : Color.gray.gradient
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.pill))
                .shadow(
                    color: (viewModel.hasChanges && viewModel.isFormValid) ? Color.blue.opacity(0.3) : Color.clear,
                    radius: 8, x: 0, y: 4
                )
            }
            .disabled(!viewModel.hasChanges || !viewModel.isFormValid || viewModel.isSaving)
            .animation(.bouncy(duration: 0.3), value: viewModel.hasChanges)
            
            // Discard Button
            Button {
                withAnimation {
                    viewModel.discardChanges()
                }
            } label: {
                Text("Discard Changes")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.hasChanges ? .red : .secondary)
            }
            .disabled(!viewModel.hasChanges || viewModel.isSaving)
            .opacity(viewModel.hasChanges ? 1 : 0.6)
        }
    }
    
    private var statusMessageOverlay: some View {
        VStack(spacing: 8) {
            if let successMessage = viewModel.successMessage {
                MessageBanner(
                    message: successMessage,
                    type: .success,
                    onDismiss: { viewModel.clearSuccess() }
                )
            }
            
            if let errorMessage = viewModel.errorMessage {
                MessageBanner(
                    message: errorMessage,
                    type: .error,
                    onDismiss: { viewModel.clearError() }
                )
            }
        }
        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
        .padding(.top, 8)
        .animation(.bouncy(duration: 0.3), value: viewModel.successMessage)
        .animation(.bouncy(duration: 0.3), value: viewModel.errorMessage)
    }
}

// MARK: - Helper Views

struct ProfileAvatarView: View {
    let selectedImage: UIImage?
    let imageURL: URL?
    let initials: String
    let hasRemovedImage: Bool
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background Circle (Gradient)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Content
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let imageURL = imageURL, !hasRemovedImage {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure:
                        Text(initials.prefix(2).uppercased())
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundStyle(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Text(initials.prefix(2).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            // Border ring
            Circle()
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Image Picker Implementation

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    var selectedImage: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = true
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        return imagePicker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.selectedImage(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(SessionManager.shared)
    }
}
