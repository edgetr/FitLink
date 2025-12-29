import SwiftUI
import PhotosUI

#if canImport(UIKit)
import UIKit
#endif

struct FriendChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var scrollToBottom = false
    @State private var showAttachmentMenu = false
    @State private var showImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var replyingTo: FriendChatMessage?
    @FocusState private var isInputFocused: Bool
    
    let friend: User
    
    init(currentUserId: String, friend: User) {
        self.friend = friend
        self._viewModel = StateObject(wrappedValue: ChatViewModel(
            currentUserId: currentUserId,
            friendId: friend.id
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            
            messageList
            
            if let reply = replyingTo {
                replyPreview(reply)
            }
            
            chatInputBar
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
        .onDisappear {
            viewModel.cleanup()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .sheet(isPresented: $showAttachmentMenu) {
            AttachmentMenuSheet(
                onSelectImage: { showImagePicker = true },
                onSelectDietPlan: { /* TODO: Plan picker */ },
                onSelectWorkoutPlan: { /* TODO: Plan picker */ }
            )
            .presentationDetents([.height(200)])
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let newItem = newItem {
                    await handleImageSelection(newItem)
                }
            }
        }
    }
    
    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            
            AvatarCircle(initials: friend.initials, size: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.headline)
                
                if viewModel.isOtherUserTyping {
                    Text("typing...")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("FitLink Friend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button {
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.isLoading && viewModel.messages.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleFactory(
                                message: message,
                                displayContent: viewModel.getDisplayContent(for: message),
                                isFromCurrentUser: viewModel.isFromCurrentUser(message),
                                onReply: { replyingTo = message },
                                replyMessage: findReplyMessage(for: message)
                            )
                            .id(message.id)
                        }
                    }
                    
                    if viewModel.isOtherUserTyping {
                        FriendTypingIndicator()
                            .id("typing")
                    }
                    
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                .padding(.vertical, GlassTokens.Padding.standard)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: scrollToBottom) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
    }
    
    private func findReplyMessage(for message: FriendChatMessage) -> FriendChatMessage? {
        guard let replyToId = message.replyToId else { return nil }
        return viewModel.messages.first { $0.id == replyToId }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Start a Conversation")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Send a message to \(friend.displayName) to start chatting!")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }
    
    private func replyPreview(_ message: FriendChatMessage) -> some View {
        HStack {
            Rectangle()
                .fill(Color.green)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.isFromCurrentUser(message) ? "You" : friend.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                
                Text(viewModel.getDisplayContent(for: message))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                replyingTo = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    private var chatInputBar: some View {
        HStack(spacing: 12) {
            Button {
                showAttachmentMenu = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)
            }
            
            TextField("Type a message...", text: $viewModel.inputText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                )
                .focused($isInputFocused)
                .disabled(viewModel.isSending)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }
            
            Button {
                sendMessage()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green, .teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    if viewModel.isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(
            .rect(
                topLeadingRadius: 20,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 20
            )
        )
        .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
    }
    
    private func sendMessage() {
        guard !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            if let replyTo = replyingTo {
                await viewModel.sendReply(to: replyTo.id)
                replyingTo = nil
            } else {
                await viewModel.sendMessage()
            }
            scrollToBottom.toggle()
        }
    }
    
    private func handleImageSelection(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            return
        }
        
        await viewModel.sendImage(imageData: data)
        scrollToBottom.toggle()
        selectedPhotoItem = nil
    }
}

struct MessageBubbleFactory: View {
    let message: FriendChatMessage
    let displayContent: String
    let isFromCurrentUser: Bool
    let onReply: () -> Void
    let replyMessage: FriendChatMessage?
    
    var body: some View {
        Group {
            switch message.type {
            case .text:
                TextMessageBubble(
                    message: message,
                    displayContent: displayContent,
                    isFromCurrentUser: isFromCurrentUser,
                    replyMessage: replyMessage
                )
            case .voice:
                VoiceMessageBubble(
                    message: message,
                    isFromCurrentUser: isFromCurrentUser
                )
            case .image:
                ImageMessageBubble(
                    message: message,
                    isFromCurrentUser: isFromCurrentUser
                )
            case .dietPlan, .workoutPlan:
                PlanShareBubble(
                    message: message,
                    isFromCurrentUser: isFromCurrentUser
                )
            case .challenge:
                ChallengeBubble(
                    message: message,
                    isFromCurrentUser: isFromCurrentUser
                )
            case .file:
                TextMessageBubble(
                    message: message,
                    displayContent: "[File: \(message.payload?.fileName ?? "Unknown")]",
                    isFromCurrentUser: isFromCurrentUser,
                    replyMessage: nil
                )
            }
        }
        .contextMenu {
            Button {
                onReply()
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            
            Button {
                UIPasteboard.general.string = displayContent
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
}

struct TextMessageBubble: View {
    let message: FriendChatMessage
    let displayContent: String
    let isFromCurrentUser: Bool
    let replyMessage: FriendChatMessage?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 6) {
                    if let reply = replyMessage {
                        ReplyPreviewInBubble(
                            content: reply.decryptedContent ?? "[Encrypted]",
                            isFromCurrentUser: isFromCurrentUser
                        )
                    }
                    
                    Text(displayContent)
                        .font(.body)
                        .foregroundStyle(isFromCurrentUser ? .white : .primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                
                HStack(spacing: 4) {
                    Text(formattedTime)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if isFromCurrentUser {
                        MessageStatusIndicator(status: message.status)
                    }
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if isFromCurrentUser {
            LinearGradient(
                colors: [.green, .teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(UIColor.secondarySystemGroupedBackground)
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}

struct ReplyPreviewInBubble: View {
    let content: String
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(isFromCurrentUser ? Color.white.opacity(0.5) : Color.green)
                .frame(width: 2)
            
            Text(content)
                .font(.caption)
                .foregroundStyle(isFromCurrentUser ? Color.white.opacity(0.8) : .secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct VoiceMessageBubble: View {
    let message: FriendChatMessage
    let isFromCurrentUser: Bool
    
    @State private var isPlaying = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            HStack(spacing: 12) {
                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(isFromCurrentUser ? .white : .green)
                }
                
                WaveformView(isPlaying: isPlaying)
                    .frame(width: 100, height: 24)
                
                Text(formatDuration(message.payload?.voiceDuration ?? 0))
                    .font(.caption)
                    .foregroundStyle(isFromCurrentUser ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if isFromCurrentUser {
            LinearGradient(
                colors: [.green, .teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(UIColor.secondarySystemGroupedBackground)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct WaveformView: View {
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 3, height: CGFloat.random(in: 4...24))
            }
        }
    }
}

struct ImageMessageBubble: View {
    let message: FriendChatMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            AsyncImage(url: URL(string: message.payload?.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } placeholder: {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 150)
                    .overlay(ProgressView())
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

struct PlanShareBubble: View {
    let message: FriendChatMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: message.type == .dietPlan ? "fork.knife" : "dumbbell.fill")
                        .foregroundStyle(.green)
                    
                    Text(message.type == .dietPlan ? "Diet Plan" : "Workout Plan")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
                
                Text(message.payload?.planTitle ?? "Shared Plan")
                    .font(.headline)
                    .foregroundStyle(isFromCurrentUser ? .white : .primary)
                
                Button {
                } label: {
                    Text("View Plan")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isFromCurrentUser
                          ? LinearGradient(colors: [.green.opacity(0.3), .teal.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [Color(UIColor.secondarySystemGroupedBackground)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
            )
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

struct ChallengeBubble: View {
    let message: FriendChatMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.orange)
                    
                    Text("Challenge!")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
                
                Text("Fitness Challenge")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 12) {
                    Button {
                    } label: {
                        Text("Accept")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                    
                    Button {
                    } label: {
                        Text("Decline")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1)
            )
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

struct MessageStatusIndicator: View {
    let status: MessageStatus
    
    var body: some View {
        switch status {
        case .sending:
            ProgressView()
                .scaleEffect(0.5)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .delivered:
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        case .read:
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundStyle(.blue)
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
}

struct AttachmentMenuSheet: View {
    let onSelectImage: () -> Void
    let onSelectDietPlan: () -> Void
    let onSelectWorkoutPlan: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 30) {
                AttachmentOption(
                    icon: "photo.fill",
                    title: "Photo",
                    color: .blue
                ) {
                    dismiss()
                    onSelectImage()
                }
                
                AttachmentOption(
                    icon: "fork.knife",
                    title: "Diet Plan",
                    color: .green
                ) {
                    dismiss()
                    onSelectDietPlan()
                }
                
                AttachmentOption(
                    icon: "dumbbell.fill",
                    title: "Workout",
                    color: .orange
                ) {
                    dismiss()
                    onSelectWorkoutPlan()
                }
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .presentationDragIndicator(.visible)
    }
}

struct AttachmentOption: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
    }
}

struct FriendTypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffset(for: index))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            
            Spacer(minLength: 60)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
            ) {
                animationOffset = -4
            }
        }
    }
    
    private func animationOffset(for index: Int) -> CGFloat {
        let delay = Double(index) * 0.15
        return animationOffset * cos(delay * .pi)
    }
}

#Preview {
    NavigationStack {
        FriendChatView(
            currentUserId: "preview-user",
            friend: User(
                id: "friend-id",
                displayName: "John Doe",
                email: "friend@example.com",
                photoURL: nil,
                friendIDs: [],
                createdAt: Date()
            )
        )
    }
}
