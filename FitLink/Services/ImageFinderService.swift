import Foundation
import UIKit

final class ImageFinderService {
    
    static let shared = ImageFinderService()
    
    private let session: URLSession
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private var diskCacheURL: URL?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
        
        setupDiskCache()
        configureCacheLimits()
    }
    
    private func setupDiskCache() {
        if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            diskCacheURL = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)
            if let url = diskCacheURL {
                try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }
    
    private func configureCacheLimits() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
    }
    
    // MARK: - Public API
    
    func fetchRecipeImage(for recipeName: String, category: String? = nil) async -> UIImage? {
        let cacheKey = generateCacheKey(recipeName: recipeName, category: category)
        
        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        if let diskImage = loadFromDisk(key: cacheKey) {
            cache.setObject(diskImage, forKey: cacheKey as NSString)
            return diskImage
        }
        
        let searchQuery = buildSearchQuery(recipeName: recipeName, category: category)
        
        if let image = await fetchFromUnsplash(query: searchQuery) {
            cacheImage(image, forKey: cacheKey)
            return image
        }
        
        return placeholderImage(for: category)
    }
    
    func fetchImage(from urlString: String) async -> UIImage? {
        let cacheKey = urlString.hashValue.description
        
        if let cached = cache.object(forKey: cacheKey as NSString) {
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
            
            cacheImage(image, forKey: cacheKey)
            return image
        } catch {
            print("ImageFinderService: Failed to fetch image: \(error.localizedDescription)")
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
        cache.removeAllObjects()
        if let diskURL = diskCacheURL {
            try? fileManager.removeItem(at: diskURL)
            try? fileManager.createDirectory(at: diskURL, withIntermediateDirectories: true)
        }
    }
    
    func clearMemoryCache() {
        cache.removeAllObjects()
    }
    
    // MARK: - Private Implementation
    
    private func generateCacheKey(recipeName: String, category: String?) -> String {
        let base = recipeName.lowercased().replacingOccurrences(of: " ", with: "_")
        if let cat = category?.lowercased() {
            return "\(cat)_\(base)"
        }
        return base
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
            print("ImageFinderService: Unsplash fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func cacheImage(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
        saveToDisk(image: image, key: key)
    }
    
    private func saveToDisk(image: UIImage, key: String) {
        guard let diskURL = diskCacheURL,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileURL = diskURL.appendingPathComponent("\(key.hashValue).jpg")
        try? data.write(to: fileURL)
    }
    
    private func loadFromDisk(key: String) -> UIImage? {
        guard let diskURL = diskCacheURL else { return nil }
        let fileURL = diskURL.appendingPathComponent("\(key.hashValue).jpg")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
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
        guard let diskURL = diskCacheURL else { return "0 MB" }
        
        var totalSize: Int64 = 0
        if let enumerator = fileManager.enumerator(at: diskURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    func getCachedImageCount() -> Int {
        guard let diskURL = diskCacheURL,
              let contents = try? fileManager.contentsOfDirectory(at: diskURL, includingPropertiesForKeys: nil) else {
            return 0
        }
        return contents.filter { $0.pathExtension == "jpg" }.count
    }
}
