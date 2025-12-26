import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    let id: String
    var displayName: String
    var email: String
    var photoURL: String?
    var friendIDs: [String]
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case photoURL = "photo_url"
        case friendIDs = "friend_ids"
        case createdAt = "created_at"
    }
    
    var initials: String {
        let names = displayName.split(separator: " ")
        let initials = names.compactMap { $0.first }.prefix(2)
        return String(initials).uppercased()
    }
    
    var hasProfileImage: Bool {
        photoURL != nil && !(photoURL?.isEmpty ?? true)
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "display_name": displayName,
            "email": email,
            "photo_url": photoURL as Any,
            "friend_ids": friendIDs,
            "created_at": createdAt
        ]
    }
    
    static func fromDictionary(_ data: [String: Any], id: String) -> User? {
        guard let displayName = data["display_name"] as? String,
              let email = data["email"] as? String else {
            return nil
        }
        
        let photoURL = data["photo_url"] as? String
        let friendIDs = data["friend_ids"] as? [String] ?? []
        let createdAt = (data["created_at"] as? Timestamp)?.dateValue() ?? Date()
        
        return User(
            id: id,
            displayName: displayName,
            email: email,
            photoURL: photoURL,
            friendIDs: friendIDs,
            createdAt: createdAt
        )
    }
    
    static var sample: User {
        User(
            id: "sample-user-id",
            displayName: "John Doe",
            email: "john@example.com",
            photoURL: nil,
            friendIDs: [],
            createdAt: Date()
        )
    }
}
