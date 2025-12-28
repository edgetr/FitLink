import SwiftUI
import Combine

@MainActor
class MemoryToastManager: ObservableObject {
    
    static let shared = MemoryToastManager()
    
    @Published var currentToast: Memory?
    @Published var isShowingToast: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var toastQueue: [Memory] = []
    private var isProcessingQueue = false
    
    private init() {
        setupSubscription()
    }
    
    private func setupSubscription() {
        Task {
            await subscribeToMemoryService()
        }
    }
    
    private func subscribeToMemoryService() async {
        await MemoryService.shared.memoryAddedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] memory in
                self?.enqueueToast(memory)
            }
            .store(in: &cancellables)
    }
    
    private func enqueueToast(_ memory: Memory) {
        toastQueue.append(memory)
        processQueue()
    }
    
    private func processQueue() {
        guard !isProcessingQueue, !toastQueue.isEmpty else { return }
        
        isProcessingQueue = true
        let memory = toastQueue.removeFirst()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentToast = memory
            isShowingToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.dismissCurrentToast()
        }
    }
    
    func dismissCurrentToast() {
        withAnimation(.easeOut(duration: 0.2)) {
            isShowingToast = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.currentToast = nil
            self?.isProcessingQueue = false
            self?.processQueue()
        }
    }
}
