import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ChatConversationView: View {
    let messages: [ChatMessage]
    let isLoading: Bool
    let isReadyToGenerate: Bool
    let readySummary: String?
    let onSendMessage: (String) -> Void
    let onGeneratePlan: () -> Void
    let onMoreQuestions: () -> Void
    
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }
                        
                        if isLoading {
                            TypingIndicatorView()
                                .id("typing")
                        }
                        
                        if isReadyToGenerate && !isLoading {
                            ReadyToGenerateView(
                                summary: readySummary,
                                onGenerate: onGeneratePlan,
                                onMoreQuestions: onMoreQuestions
                            )
                            .id("ready-buttons")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: isLoading) { _, loading in
                    if loading {
                        withAnimation {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }
            
            if !isReadyToGenerate {
                ChatInputBar(
                    text: $inputText,
                    isLoading: isLoading,
                    placeholder: "Type your response...",
                    accentColor: .green,
                    onSend: {
                        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        inputText = ""
                        isInputFocused = false
                        onSendMessage(text)
                    }
                )
                .focused($isInputFocused)
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
    }
}

// MARK: - ChatBubbleView

struct ChatBubbleView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else {
                assistantAvatar
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Text(formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
    
    private var assistantAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.green, .teal],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            )
    }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
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

// MARK: - TypingIndicatorView

struct TypingIndicatorView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.green, .teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                )
            
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

// MARK: - ReadyToGenerateView

struct ReadyToGenerateView: View {
    let summary: String?
    let onGenerate: () -> Void
    let onMoreQuestions: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if let summary = summary, !summary.isEmpty {
                GlassCard(tint: Color.green.opacity(0.1)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Ready to Create Your Plan")
                                .font(.headline)
                        }
                        
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            
            HStack(spacing: 12) {
                GlassTextPillButton(
                    "More Questions",
                    icon: "questionmark.bubble",
                    tint: .secondary
                ) {
                    onMoreQuestions()
                }
                
                GlassTextPillButton(
                    "Generate Plan",
                    icon: "sparkles",
                    tint: .green,
                    isProminent: true
                ) {
                    onGenerate()
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - ChatInputBar

struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    var placeholder: String = "Type a message..."
    var accentColor: Color = .blue
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TextField(placeholder, text: $text)
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
                    .focused($isFocused)
                    .disabled(isLoading)
                    .submitLabel(.send)
                    .onSubmit {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend()
                        }
                    }
                
                sendButton
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
    }
    
    private var sendButton: some View {
        Button(action: onSend) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44)
            .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
    }
}
