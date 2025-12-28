import Foundation
import UIKit

final class ImageFinderService {
    
    static let shared = ImageFinderService()
    
    private let session: URLSession
    private let cacheManager = CacheManager.shared
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    func fetchRecipeImage(for recipeName: String, category: String? = nil) async -> UIImage? {
        let cacheKey = generateCacheKey(recipeName: recipeName, category: category)
        
        if let cached = cacheManager.getCachedImage(forKey: cacheKey, checkDisk: true) {
            return cached
        }
        
        let searchQuery = buildSearchQuery(recipeName: recipeName, category: category)
        
        if let image = await fetchFromUnsplash(query: searchQuery) {
            cacheManager.cacheImage(image, forKey: cacheKey, persistToDisk: true)
            cacheManager.recordNetworkFetch()
            return image
        }
        
        return placeholderImage(for: category)
    }
    
    func fetchImage(from urlString: String) async -> UIImage? {
        let cacheKey = cacheManager.stableKey(for: urlString)
        
        if let cached = cacheManager.getCachedImage(forKey: cacheKey, checkDisk: true) {
            return cached
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }
            
            cacheManager.cacheImage(image, forKey: cacheKey, persistToDisk: true)
            cacheManager.recordNetworkFetch()
            return image
        } catch {
            AppLogger.shared.debug("Failed to fetch image: \(error.localizedDescription)", category: .image)
            return nil
        }
    }
    
    func prefetchImages(for recipeNames: [String]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for name in recipeNames.prefix(5) {
                    group.addTask {
                        _ = await self.fetchRecipeImage(for: name)
                    }
                }
            }
        }
    }
    
    func clearCache() {
        cacheManager.clearImageCache()
        cacheManager.clearDiskCache()
    }
    
    func clearMemoryCache() {
        cacheManager.clearImageCache()
    }
    
    // MARK: - Private Implementation
    
    private func generateCacheKey(recipeName: String, category: String?) -> String {
        let base = recipeName.lowercased().replacingOccurrences(of: " ", with: "_")
        if let cat = category?.lowercased() {
            return "recipe_\(cat)_\(base)"
        }
        return "recipe_\(base)"
    }
    
    private func buildSearchQuery(recipeName: String, category: String?) -> String {
        var query = recipeName
        if let cat = category {
            query = "\(cat) \(recipeName)"
        }
        return query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? recipeName
    }
    
    private func fetchFromUnsplash(query: String) async -> UIImage? {
        let urlString = "https://source.unsplash.com/400x300/?\(query),food"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }
            return image
        } catch {
            AppLogger.shared.debug("Unsplash fetch failed: \(error.localizedDescription)", category: .image)
            return nil
        }
    }
    
    private func placeholderImage(for category: String?) -> UIImage? {
        let systemName: String
        switch category?.lowercased() {
        case "breakfast":
            systemName = "cup.and.saucer.fill"
        case "lunch", "dinner":
            systemName = "fork.knife"
        case "snack":
            systemName = "carrot.fill"
        case "protein":
            systemName = "fish.fill"
        case "vegetable":
            systemName = "leaf.fill"
        default:
            systemName = "fork.knife.circle.fill"
        }
        
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
        return UIImage(systemName: systemName, withConfiguration: config)?
            .withTintColor(.systemGray3, renderingMode: .alwaysOriginal)
    }
}

extension ImageFinderService {
    
    func getCacheSize() -> String {
        let sizeInBytes = cacheManager.approximateCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(sizeInBytes))
    }
    
    func getCacheMetrics() -> CacheMetrics {
        cacheManager.getMetrics()
    }
}
