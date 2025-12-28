import SwiftUI

enum MemoriesLoadState {
    case idle
    case loading
    case loaded
    case error(String)
}

struct MemoriesView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var memories: [Memory] = []
    @State private var loadState: MemoriesLoadState = .idle
    @State private var showClearAllAlert = false
    @State private var isDeleting = false
    
    private var groupedMemories: [MemoryType: [Memory]] {
        Dictionary(grouping: memories, by: { $0.type })
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            switch loadState {
            case .idle, .loading:
                ProgressView("Loading memories...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            case .error(let message):
                errorStateView(message: message)
                
            case .loaded:
                if memories.isEmpty {
                    emptyStateView
                } else {
                    memoriesListView
                }
            }
        }
        .navigationTitle("Memories")
        .task {
            await loadMemories()
        }
        .refreshable {
            await loadMemories()
        }
        .alert("Clear All Memories?", isPresented: $showClearAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                Task {
                    await clearAll()
                }
            }
        } message: {
            Text("This will remove all learned preferences and history. This action cannot be undone.")
        }
    }
    
    private var memoriesListView: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                
                ForEach(MemoryType.allCases, id: \.self) { type in
                    if let items = groupedMemories[type], !items.isEmpty {
                        sectionView(for: type, items: items)
                    }
                }
                
                clearAllButton
            }
            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
            .padding(.vertical, GlassTokens.Layout.pageBottomInset)
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What FitLink has learned about you")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text("These preferences personalize your plans.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
                .padding(.top, 8)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)
            
            Text("No memories yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("As you use FitLink, I'll learn what\nexercises and meals you prefer.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding()
    }
    
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Failed to load memories")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await loadMemories()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func sectionView(for type: MemoryType, items: [Memory]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(type.displayName.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .padding(.leading, 4)
            
            VStack(spacing: 12) {
                ForEach(items) { memory in
                    MemoryRowView(memory: memory) {
                        Task {
                            await delete(memory)
                        }
                    }
                }
            }
        }
    }
    
    private var clearAllButton: some View {
        Button(action: {
            showClearAllAlert = true
        }) {
            GlassCard(tint: .red, isInteractive: true) {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text("Clear All Memories")
                }
                .foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .disabled(isDeleting)
        .padding(.top, 24)
    }
    
    private func loadMemories() async {
        guard let userId = sessionManager.currentUserID else {
            loadState = .error("Not signed in")
            return
        }
        
        loadState = .loading
        
        do {
            let fetchedMemories = try await MemoryService.shared.getAllMemories(userId: userId)
            memories = fetchedMemories
            loadState = .loaded
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }
    
    private func delete(_ memory: Memory) async {
        guard let userId = sessionManager.currentUserID else { return }
        
        do {
            try await MemoryService.shared.deleteMemory(userId: userId, memoryId: memory.id)
            withAnimation {
                memories.removeAll { $0.id == memory.id }
            }
        } catch {
            AppLogger.shared.error("Failed to delete memory: \(error.localizedDescription)", category: .user)
        }
    }
    
    private func clearAll() async {
        guard let userId = sessionManager.currentUserID else { return }
        
        isDeleting = true
        
        do {
            try await MemoryService.shared.deleteAllMemories(userId: userId)
            withAnimation {
                memories.removeAll()
            }
        } catch {
            AppLogger.shared.error("Failed to clear memories: \(error.localizedDescription)", category: .user)
        }
        
        isDeleting = false
    }
}

#Preview {
    NavigationStack {
        MemoriesView()
            .environmentObject(SessionManager.shared)
    }
}
