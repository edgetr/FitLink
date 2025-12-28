//
//  CacheManager.swift
//  FitLink
//
//  Created on 25.12.2025.
//

import Foundation
import UIKit
import CryptoKit

// MARK: - Cache Policy

/// Defines TTL policies for different cache domains
enum CacheDomain {
    case image
    case apiResponse
    case userProfile
    
    var ttl: TimeInterval {
        switch self {
        case .image:
            return 7 * 24 * 60 * 60 // 7 days
        case .apiResponse:
            return 30 * 60 // 30 minutes
        case .userProfile:
            return 60 * 60 // 1 hour
        }
    }
}

/// Cache metrics for instrumentation
struct CacheMetrics {
    var memoryHits: Int = 0
    var memoryMisses: Int = 0
    var diskHits: Int = 0
    var diskMisses: Int = 0
    var networkFetches: Int = 0
    
    var memoryHitRate: Double {
        let total = memoryHits + memoryMisses
        return total > 0 ? Double(memoryHits) / Double(total) : 0
    }
    
    var diskHitRate: Double {
        let total = diskHits + diskMisses
        return total > 0 ? Double(diskHits) / Double(total) : 0
    }
}

/// Centralized cache manager for images and API responses.
/// Uses NSCache for memory-efficient caching with automatic cleanup on memory pressure.
final class CacheManager {
    
    // MARK: - Singleton
    
    static let shared = CacheManager()
    
    // MARK: - Cache Types
    
    /// Wrapper for cached responses with TTL support
    private class CachedResponse {
        let data: Data
        let expirationDate: Date
        
        var isExpired: Bool {
            Date() > expirationDate
        }
        
        init(data: Data, ttl: TimeInterval) {
            self.data = data
            self.expirationDate = Date().addingTimeInterval(ttl)
        }
    }
    
    // MARK: - Private Properties
    
    /// Image cache using NSCache for automatic memory management
    private let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.name = "com.fitlink.imageCache"
        cache.countLimit = 100 // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB limit
        return cache
    }()
    
    /// Response cache for API responses with TTL
    private let responseCache: NSCache<NSString, CachedResponse> = {
        let cache = NSCache<NSString, CachedResponse>()
        cache.name = "com.fitlink.responseCache"
        cache.countLimit = 50 // Max 50 responses
        cache.totalCostLimit = 10 * 1024 * 1024 // 10 MB limit
        return cache
    }()
    
    /// Default TTL for cached responses (30 minutes)
    private let defaultResponseTTL: TimeInterval = 30 * 60
    
    /// Lock for thread-safe disk cache operations
    private let diskCacheLock = NSLock()
    
    private lazy var diskCacheDirectory: URL? = {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let fitlinkCache = cacheDir?.appendingPathComponent("FitLinkCache", isDirectory: true)
        
        if let dir = fitlinkCache {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        return fitlinkCache
    }()
    
    private var metrics = CacheMetrics()
    private let metricsLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryWarningObserver()
        log("CacheManager initialized")
    }
    
    // MARK: - Stable Key Generation
    
    func stableKey(for input: String) -> String {
        let inputData = Data(input.utf8)
        let hash = SHA256.hash(data: inputData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func stableKey(for url: URL) -> String {
        stableKey(for: url.absoluteString)
    }
    
    // MARK: - Image Cache Methods
    
    func cacheImage(_ image: UIImage, forKey key: String, persistToDisk: Bool = false) {
        let cacheKey = NSString(string: key)
        let cost = Int(image.size.width * image.size.height * image.scale * 4)
        imageCache.setObject(image, forKey: cacheKey, cost: cost)
        log("Cached image for key: \(key.prefix(50))...")
        
        if persistToDisk, let data = image.jpegData(compressionQuality: 0.8) {
            let diskKey = stableKey(for: key) + ".jpg"
            saveToDisk(data, forKey: diskKey)
        }
    }
    
    func getCachedImage(forKey key: String, checkDisk: Bool = false) -> UIImage? {
        let cacheKey = NSString(string: key)
        
        if let image = imageCache.object(forKey: cacheKey) {
            recordMetric { $0.memoryHits += 1 }
            log("Memory cache hit for image: \(key.prefix(50))...")
            return image
        }
        recordMetric { $0.memoryMisses += 1 }
        
        if checkDisk {
            let diskKey = stableKey(for: key) + ".jpg"
            if let data = loadFromDisk(forKey: diskKey), let image = UIImage(data: data) {
                imageCache.setObject(image, forKey: cacheKey)
                recordMetric { $0.diskHits += 1 }
                log("Disk cache hit for image: \(key.prefix(50))...")
                return image
            }
            recordMetric { $0.diskMisses += 1 }
        }
        
        log("Cache miss for image: \(key.prefix(50))...")
        return nil
    }
    
    /// Removes a cached image
    /// - Parameter key: The cache key
    func removeImage(forKey key: String) {
        let cacheKey = NSString(string: key)
        imageCache.removeObject(forKey: cacheKey)
    }
    
    /// Clears all cached images
    func clearImageCache() {
        imageCache.removeAllObjects()
        log("Image cache cleared")
    }
    
    // MARK: - Response Cache Methods
    
    /// Caches an API response with TTL
    /// - Parameters:
    ///   - data: The response data to cache
    ///   - key: The cache key (typically the request identifier)
    ///   - ttl: Time-to-live in seconds (default: 30 minutes)
    func cacheResponse(_ data: Data, forKey key: String, ttl: TimeInterval? = nil) {
        let cacheKey = NSString(string: key)
        let effectiveTTL = ttl ?? defaultResponseTTL
        let cachedResponse = CachedResponse(data: data, ttl: effectiveTTL)
        responseCache.setObject(cachedResponse, forKey: cacheKey, cost: data.count)
        log("Cached response for key: \(key.prefix(50))... (TTL: \(Int(effectiveTTL))s)")
    }
    
    /// Retrieves a cached response if not expired
    /// - Parameter key: The cache key
    /// - Returns: The cached data if available and not expired
    func getCachedResponse(forKey key: String) -> Data? {
        let cacheKey = NSString(string: key)
        
        guard let cachedResponse = responseCache.object(forKey: cacheKey) else {
            log("Cache miss for response: \(key.prefix(50))...")
            return nil
        }
        
        if cachedResponse.isExpired {
            responseCache.removeObject(forKey: cacheKey)
            log("Cache expired for response: \(key.prefix(50))...")
            return nil
        }
        
        log("Cache hit for response: \(key.prefix(50))...")
        return cachedResponse.data
    }
    
    /// Removes a cached response
    /// - Parameter key: The cache key
    func removeResponse(forKey key: String) {
        let cacheKey = NSString(string: key)
        responseCache.removeObject(forKey: cacheKey)
    }
    
    /// Clears all cached responses
    func clearResponseCache() {
        responseCache.removeAllObjects()
        log("Response cache cleared")
    }
    
    // MARK: - Disk Cache Methods
    
    /// Saves data to disk cache
    /// - Parameters:
    ///   - data: The data to cache
    ///   - key: The cache key
    func saveToDisk(_ data: Data, forKey key: String) {
        guard let cacheDir = diskCacheDirectory else { return }
        
        let sanitizedKey = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let fileURL = cacheDir.appendingPathComponent(sanitizedKey)
        
        diskCacheLock.lock()
        defer { diskCacheLock.unlock() }
        
        do {
            try data.write(to: fileURL, options: .atomic)
            log("Saved to disk cache: \(sanitizedKey.prefix(50))...")
        } catch {
            log("Failed to save to disk cache: \(error.localizedDescription)")
        }
    }
    
    /// Loads data from disk cache
    /// - Parameter key: The cache key
    /// - Returns: The cached data if available
    func loadFromDisk(forKey key: String) -> Data? {
        guard let cacheDir = diskCacheDirectory else { return nil }
        
        let sanitizedKey = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let fileURL = cacheDir.appendingPathComponent(sanitizedKey)
        
        diskCacheLock.lock()
        defer { diskCacheLock.unlock() }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            log("Loaded from disk cache: \(sanitizedKey.prefix(50))...")
            return data
        } catch {
            log("Failed to load from disk cache: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Removes data from disk cache
    /// - Parameter key: The cache key
    func removeFromDisk(forKey key: String) {
        guard let cacheDir = diskCacheDirectory else { return }
        
        let sanitizedKey = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let fileURL = cacheDir.appendingPathComponent(sanitizedKey)
        
        diskCacheLock.lock()
        defer { diskCacheLock.unlock() }
        
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// Clears disk cache
    func clearDiskCache() {
        guard let cacheDir = diskCacheDirectory else { return }
        
        diskCacheLock.lock()
        defer { diskCacheLock.unlock() }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
            log("Disk cache cleared")
        } catch {
            log("Failed to clear disk cache: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Clear All
    
    /// Clears all caches (memory and disk)
    func clearAllCaches() {
        clearImageCache()
        clearResponseCache()
        clearDiskCache()
        log("All caches cleared")
    }
    
    /// Returns approximate total cache size in bytes
    func approximateCacheSize() -> Int {
        var size = 0
        
        // Disk cache size
        if let cacheDir = diskCacheDirectory {
            diskCacheLock.lock()
            defer { diskCacheLock.unlock() }
            
            if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for file in files {
                    if let fileSize = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        size += fileSize
                    }
                }
            }
        }
        
        return size
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        log("Received memory warning - clearing memory caches only (preserving disk cache)")
        clearImageCache()
        clearResponseCache()
    }
    
    func clearMemoryCachesOnly() {
        clearImageCache()
        clearResponseCache()
        log("Cleared memory caches only (disk cache preserved)")
    }
    
    // MARK: - Metrics
    
    private func recordMetric(_ update: (inout CacheMetrics) -> Void) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        update(&metrics)
    }
    
    func recordNetworkFetch() {
        recordMetric { $0.networkFetches += 1 }
    }
    
    func getMetrics() -> CacheMetrics {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return metrics
    }
    
    func resetMetrics() {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        metrics = CacheMetrics()
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [CacheManager] \(message)")
        #endif
    }
}

// MARK: - Convenience Extensions

extension CacheManager {
    
    /// Caches a Codable object as JSON
    func cacheObject<T: Encodable>(_ object: T, forKey key: String, ttl: TimeInterval? = nil) {
        do {
            let data = try JSONEncoder().encode(object)
            cacheResponse(data, forKey: key, ttl: ttl)
        } catch {
            log("Failed to encode object for caching: \(error.localizedDescription)")
        }
    }
    
    /// Retrieves a cached Codable object
    func getCachedObject<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        guard let data = getCachedResponse(forKey: key) else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            log("Failed to decode cached object: \(error.localizedDescription)")
            return nil
        }
    }
}
