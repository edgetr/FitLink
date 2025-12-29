import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(Lottie)
import Lottie

/// Centralized manager for Lottie animation caching, preloading, and memory management.
/// Thread-safe singleton that handles animation lifecycle.
final class LottieManager {
    
    // MARK: - Singleton
    
    static let shared = LottieManager()
    
    // MARK: - Private Properties
    
    private let animationCache = NSCache<NSString, LottieAnimationWrapper>()
    private let preloadQueue = DispatchQueue(label: "com.fitlink.lottie.preload", qos: .utility)
    private let cacheAccessQueue = DispatchQueue(label: "com.fitlink.lottie.cache", attributes: .concurrent)
    
    private var isPreloaded = false
    
    // MARK: - Initialization
    
    private init() {
        // Configure cache limits
        animationCache.countLimit = 15  // Max 15 animations in memory
        animationCache.totalCostLimit = 50 * 1024 * 1024  // 50MB limit
        
        // Listen for memory warnings
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public API
    
    /// Preloads P0 animations for instant display. Call during app launch.
    func preloadPriorityAnimations() {
        guard !isPreloaded else { return }
        
        let priorityAnimations: [LottieAnimationType] = [
            .successCheckmark,
            .fitnessLoader,
            .brainThinking
        ]
        
        preloadQueue.async { [weak self] in
            for type in priorityAnimations {
                self?.loadAndCache(type)
            }
            self?.isPreloaded = true
            #if DEBUG
            print("[LottieManager] Preloaded \(priorityAnimations.count) priority animations")
            #endif
        }
    }
    
    /// Preloads all animations in the background. Call after initial UI is displayed.
    func preloadAllAnimations() {
        preloadQueue.async { [weak self] in
            for type in LottieAnimationType.allCases {
                self?.loadAndCache(type)
            }
            #if DEBUG
            print("[LottieManager] Preloaded all \(LottieAnimationType.allCases.count) animations")
            #endif
        }
    }
    
    /// Retrieves a cached animation, if available.
    func getCachedAnimation(named name: String) -> LottieAnimation? {
        var result: LottieAnimation?
        cacheAccessQueue.sync {
            result = animationCache.object(forKey: name as NSString)?.animation
        }
        return result
    }
    
    /// Caches an animation for reuse.
    func cacheAnimation(_ animation: LottieAnimation, named name: String) {
        let wrapper = LottieAnimationWrapper(animation: animation)
        let cost = estimateCost(for: animation)
        cacheAccessQueue.async(flags: .barrier) { [weak self] in
            self?.animationCache.setObject(wrapper, forKey: name as NSString, cost: cost)
        }
    }
    
    /// Clears all cached animations. Use during memory pressure.
    func clearCache() {
        cacheAccessQueue.async(flags: .barrier) { [weak self] in
            self?.animationCache.removeAllObjects()
            self?.isPreloaded = false
        }
        #if DEBUG
        print("[LottieManager] Cache cleared")
        #endif
    }
    
    /// Returns whether Reduce Motion is enabled (for fallback decisions).
    var isReduceMotionEnabled: Bool {
        #if canImport(UIKit)
        return UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }
    
    // MARK: - Private Helpers
    
    private func loadAndCache(_ type: LottieAnimationType) {
        guard getCachedAnimation(named: type.fileName) == nil else { return }
        
        if let animation = LottieAnimation.named(type.fileName, bundle: .main) {
            cacheAnimation(animation, named: type.fileName)
        }
    }
    
    private func estimateCost(for animation: LottieAnimation) -> Int {
        // Rough estimate: 100KB per second of animation at 60fps
        let durationSeconds = animation.duration
        return Int(durationSeconds * 100 * 1024)
    }
    
    @objc private func handleMemoryWarning() {
        // Keep only P0 animations, clear the rest
        let priorityNames = Set([
            LottieAnimationType.successCheckmark.fileName,
            LottieAnimationType.fitnessLoader.fileName,
            LottieAnimationType.brainThinking.fileName
        ])
        
        cacheAccessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // NSCache doesn't support iteration, so we clear and reload priorities
            self.animationCache.removeAllObjects()
            
            for name in priorityNames {
                if let animation = LottieAnimation.named(name, bundle: .main) {
                    let wrapper = LottieAnimationWrapper(animation: animation)
                    self.animationCache.setObject(wrapper, forKey: name as NSString)
                }
            }
        }
        
        #if DEBUG
        print("[LottieManager] Memory warning handled - cache reduced to priority animations")
        #endif
    }
}

// MARK: - Cache Wrapper

/// Wrapper class to store LottieAnimation in NSCache (requires reference type).
private final class LottieAnimationWrapper {
    let animation: LottieAnimation
    
    init(animation: LottieAnimation) {
        self.animation = animation
    }
}

#else

// MARK: - Stub Implementation (when Lottie not available)

/// Stub manager when Lottie is not installed
final class LottieManager {
    static let shared = LottieManager()
    private init() {}
    
    func preloadPriorityAnimations() {}
    func preloadAllAnimations() {}
    func clearCache() {}
    
    var isReduceMotionEnabled: Bool {
        #if canImport(UIKit)
        return UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }
}

#endif
