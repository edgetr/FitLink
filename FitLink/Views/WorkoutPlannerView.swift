import SwiftUI

struct WorkoutPlannerView: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Progress
            HStack {
                Button {
                    withAnimation {
                        viewModel.cancelWizard()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemGroupedBackground), in: Circle())
                }
                
                Spacer()
                
                Text("AI Planner")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.currentQuestionIndex + 1)/\(viewModel.questionQueue.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(8)
                    .background(Color(UIColor.secondarySystemGroupedBackground), in: Capsule())
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            
            // Chat Content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        // Introduction Message
                        MessageRowView(
                            message: "I need a few more details to build your perfect plan.",
                            isUser: false
                        )
                        
                        // History
                        ForEach(0..<viewModel.currentQuestionIndex, id: \.self) { index in
                            let question = viewModel.questionQueue[index]
                            
                            MessageRowView(message: question.text, isUser: false)
                            
                            if let answer = viewModel.wizardAnswers[question.text] {
                                MessageRowView(message: answer.stringValue, isUser: true)
                            }
                        }
                        
                        // Current Question
                        if let question = viewModel.currentQuestion {
                            MessageRowView(message: question.text, isUser: false)
                                .id("currentQuestion")
                        }
                    }
                    .padding()
                    .padding(.bottom, 100) // Space for input
                }
                .onChange(of: viewModel.currentQuestionIndex) { _ in
                    withAnimation {
                        proxy.scrollTo("currentQuestion", anchor: .bottom)
                    }
                }
            }
            
            // Input Area
            if let question = viewModel.currentQuestion {
                VStack(spacing: 12) {
                    // Hint if available
                    if let hint = question.hint {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    PlannerInputView(question: question) { answer in
                        withAnimation {
                            viewModel.nextQuestion(withAnswer: answer)
                        }
                    }
                    
                    HStack {
                        if viewModel.currentQuestionIndex == 0 {
                            Button("Start Over") {
                                withAnimation {
                                    viewModel.startOver()
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                        
                        Spacer()
                        
                        if !question.isRequired {
                            Button("Skip for now") {
                                withAnimation {
                                    viewModel.skipCurrent()
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(
                    .rect(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 20
                    )
                )
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Message Row
struct MessageRowView: View {
    let message: String
    let isUser: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if !isUser {
                // AI Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.white)
                    )
            } else {
                Spacer()
            }
            
            // Bubble
            Text(message)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if isUser {
                            Color.blue
                        } else {
                            Color(UIColor.secondarySystemGroupedBackground)
                        }
                    }
                )
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                )
                // Add tail effect via corner radius if desired, or keep it simple bubble
            
            if isUser {
                // User Avatar
                Circle()
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
            } else {
                Spacer()
            }
        }
    }
}

// MARK: - Input View
struct PlannerInputView: View {
    let question: FollowUpQuestion
    let onAnswer: (AnswerValue) -> Void
    
    @State private var textInput: String = ""
    @State private var numberInput: String = ""
    
    var body: some View {
        VStack {
            switch question.answerKind {
            case .text:
                HStack {
                    TextField("Type your answer...", text: $textInput)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.send)
                        .onSubmit {
                            if !textInput.isEmpty {
                                onAnswer(.text(textInput))
                                textInput = ""
                            }
                        }
                    
                    Button {
                        if !textInput.isEmpty {
                            onAnswer(.text(textInput))
                            textInput = ""
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .disabled(textInput.isEmpty)
                }
                
            case .number:
                HStack {
                    TextField("Enter number...", text: $numberInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit {
                            if let val = Int(numberInput) {
                                onAnswer(.number(val))
                                numberInput = ""
                            }
                        }
                    
                    Button {
                        if let val = Int(numberInput) {
                            onAnswer(.number(val))
                            numberInput = ""
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .disabled(Int(numberInput) == nil)
                }
                
            case .choice:
                if let choices = question.choices {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(choices, id: \.self) { choice in
                                Button {
                                    onAnswer(.selected(choice))
                                } label: {
                                    Text(choice)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(Color.blue.opacity(0.3))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
            case .binary:
                HStack(spacing: 20) {
                    Button {
                        onAnswer(.boolean(true))
                    } label: {
                        Label("Yes", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        onAnswer(.boolean(false))
                    } label: {
                        Label("No", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}
