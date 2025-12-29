# Friends Chat Architecture & Implementation Plan

**Version:** 1.1
**Date:** 2025-12-29
**Status:** Proposed
**Reference:** Based on iOS 26 Liquid Glass Design Patterns

---

## 1. Overview

The Friends Chat feature enables real-time, secure, end-to-end encrypted communication between FitLink users. Beyond basic messaging, it serves as a social hub for health and fitness by allowing users to share AI-generated Diet and Workout plans, track each other's activity levels (steps, streaks), challenge friends to goals, and maintain social motivation.

### Key Value Propositions:
- **Real-time Sync**: Instant message delivery via Firestore.
- **End-to-End Encryption**: Messages encrypted on-device, unreadable by server.
- **Contextual Sharing**: One-tap sharing of generated plans.
- **Activity Transparency**: Stay updated on friends' fitness progress via integrated profile activities.
- **Social Motivation**: Challenge friends, celebrate achievements, and stay accountable.
- **Liquid Glass UI**: A visually stunning, immersive chat experience following the FitLink design system.

---

## 2. Architecture

The feature follows the established FitLink architecture patterns: Services as actors, ViewModels as @MainActor classes, and Views as SwiftUI components using GlassTokens.

### 2.1 Components
- **Models**: `FriendChat` (thread metadata), `FriendChatMessage` (individual messages), `Challenge` (friend challenges).
- **Services**: 
    - `ChatService` (Actor): Manages Firestore listeners, message sending, and media uploads.
    - `ChatEncryptionService` (Actor): Handles E2E encryption key exchange and message encryption/decryption.
    - `VoiceMessageService` (Actor): Records, compresses, and uploads voice messages.
    - `ChallengeService` (Actor): Manages friend-to-friend challenges.
- **ViewModels**: `ChatViewModel` (@MainActor) manages UI state, message grouping, typing indicators, and input handling.
- **Views**: 
    - `FriendChatView`: Main conversation container.
    - `GlassChatInputBar`: Liquid Glass input with attachment capabilities.
    - `FriendProfileView`: Social dashboard for a specific friend.
    - `ActivityFeedView`: Achievement feed for friends.

---

## 3. Data Models (Firestore Schema)

### 3.1 `friend_chats` (Collection)
Maintains the state of a conversation between two users.

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique chat ID (e.g., `user1_user2` deterministic) |
| `participant_ids` | Array<String> | IDs of the two friends |
| `last_message` | Map | Summary of the last message sent (encrypted preview) |
| `updated_at` | Timestamp | Last activity in the chat |
| `created_at` | Timestamp | Chat initialization date |
| `typing_status` | Map | `{ "user_id": timestamp }` for typing indicators |
| `encryption_initialized` | Boolean | Whether key exchange is complete |

### 3.2 `friend_messages` (Sub-collection of `friend_chats`)
Individual messages within a chat.

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique message ID |
| `sender_id` | String | ID of the sender |
| `type` | String | `text`, `image`, `file`, `diet_plan`, `workout_plan`, `voice`, `challenge` |
| `encrypted_content` | String | Base64-encoded encrypted message content |
| `iv` | String | Initialization vector for decryption |
| `payload` | Map | Encrypted metadata for non-text types (e.g., `plan_id`, `voice_url`) |
| `timestamp` | Timestamp | Send time |
| `status` | String | `sent`, `delivered`, `read` |
| `read_at` | Timestamp | When recipient read the message (for read receipts) |
| `reply_to` | String? | Message ID being replied to (for quote/reply) |

### 3.3 `user_keys` (Collection)
Stores public keys for E2E encryption.

| Field | Type | Description |
|-------|------|-------------|
| `user_id` | String | User ID |
| `public_key` | String | Base64-encoded public key (Curve25519) |
| `created_at` | Timestamp | Key generation date |
| `device_id` | String | Device identifier for multi-device support |

### 3.4 `challenges` (Sub-collection of `friend_chats`)
Friend-to-friend fitness challenges.

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique challenge ID |
| `challenger_id` | String | Who issued the challenge |
| `challenged_id` | String | Who received the challenge |
| `type` | String | `steps`, `calories`, `workout_count`, `streak` |
| `target` | Number | Goal value (e.g., 10000 steps) |
| `duration_days` | Number | Challenge duration |
| `status` | String | `pending`, `active`, `completed`, `declined` |
| `progress` | Map | `{ "user_id": current_value }` |
| `winner_id` | String? | Winner when completed |
| `created_at` | Timestamp | Challenge creation date |
| `ends_at` | Timestamp | Challenge end date |

### 3.5 `activity_feed` (Collection)
Public achievements that friends can see.

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique feed item ID |
| `user_id` | String | Who achieved this |
| `type` | String | `streak_milestone`, `challenge_won`, `plan_completed`, `goal_reached` |
| `title` | String | Achievement title |
| `description` | String | Achievement description |
| `metadata` | Map | Additional context (e.g., streak count, plan name) |
| `timestamp` | Timestamp | When achieved |
| `reactions` | Map | `{ "user_id": "emoji" }` |

---

## 4. End-to-End Encryption Architecture

### 4.1 Overview
FitLink uses a simplified Signal-inspired protocol for E2E encryption, ensuring messages are encrypted on the sender's device and can only be decrypted by the recipient.

### 4.2 Encryption Stack
- **Key Exchange**: X25519 (Curve25519 Diffie-Hellman)
- **Message Encryption**: AES-256-GCM
- **Key Derivation**: HKDF-SHA256
- **Library**: Apple CryptoKit (native, no third-party dependencies)

### 4.3 Key Exchange Flow

```
┌─────────────┐                              ┌─────────────┐
│   User A    │                              │   User B    │
└──────┬──────┘                              └──────┬──────┘
       │                                            │
       │  1. Generate key pair (Curve25519)         │
       │     Store private key in Keychain          │
       │     Upload public key to Firestore         │
       │                                            │
       │  2. Fetch User B's public key              │
       │◄───────────────────────────────────────────│
       │                                            │
       │  3. Derive shared secret (X25519)          │
       │     sharedSecret = X25519(myPrivate,       │
       │                          theirPublic)      │
       │                                            │
       │  4. Derive encryption key (HKDF)           │
       │     encKey = HKDF(sharedSecret,            │
       │                   salt: chatId,            │
       │                   info: "FitLinkChat")     │
       │                                            │
       │  5. Encrypt message with AES-256-GCM       │
       │     ciphertext = AES.seal(plaintext,       │
       │                           key: encKey)     │
       │                                            │
       │  6. Send encrypted message to Firestore    │
       │────────────────────────────────────────────►
       │                                            │
       │  7. User B fetches, derives same key,      │
       │     decrypts with AES-256-GCM              │
       │                                            │
```

### 4.4 Implementation: `ChatEncryptionService`

```swift
import CryptoKit
import Security

actor ChatEncryptionService {
    private let keychain = KeychainService.shared
    
    // MARK: - Key Generation
    
    func generateKeyPair() throws -> (privateKey: Curve25519.KeyAgreement.PrivateKey, 
                                       publicKey: Data) {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey.rawRepresentation
        
        // Store private key in Keychain
        try keychain.store(privateKey.rawRepresentation, for: "chat_private_key")
        
        return (privateKey, publicKey)
    }
    
    // MARK: - Shared Secret Derivation
    
    func deriveSharedSecret(theirPublicKey: Data, chatId: String) throws -> SymmetricKey {
        // Retrieve our private key from Keychain
        guard let privateKeyData = try keychain.retrieve(for: "chat_private_key") else {
            throw EncryptionError.privateKeyNotFound
        }
        
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
        let theirKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: theirPublicKey)
        
        // X25519 key agreement
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: theirKey)
        
        // Derive encryption key using HKDF
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: chatId.data(using: .utf8)!,
            sharedInfo: "FitLinkChat".data(using: .utf8)!,
            outputByteCount: 32
        )
        
        return symmetricKey
    }
    
    // MARK: - Message Encryption
    
    func encrypt(message: String, with key: SymmetricKey) throws -> (ciphertext: Data, nonce: Data) {
        let messageData = message.data(using: .utf8)!
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(messageData, using: key, nonce: nonce)
        
        return (sealedBox.ciphertext + sealedBox.tag, Data(nonce))
    }
    
    // MARK: - Message Decryption
    
    func decrypt(ciphertext: Data, nonce: Data, with key: SymmetricKey) throws -> String {
        let nonceObj = try AES.GCM.Nonce(data: nonce)
        
        // Split ciphertext and tag (last 16 bytes)
        let tagLength = 16
        let encryptedData = ciphertext.dropLast(tagLength)
        let tag = ciphertext.suffix(tagLength)
        
        let sealedBox = try AES.GCM.SealedBox(nonce: nonceObj, ciphertext: encryptedData, tag: tag)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let message = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        
        return message
    }
}

enum EncryptionError: Error {
    case privateKeyNotFound
    case publicKeyNotFound
    case keyDerivationFailed
    case encryptionFailed
    case decryptionFailed
}
```

### 4.5 Security Properties
- **Forward Secrecy**: Consider implementing Double Ratchet for per-message keys (future enhancement).
- **Key Storage**: Private keys stored in iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- **No Server Access**: Firestore only stores encrypted ciphertext; server cannot read messages.
- **Verification**: Future: QR code key verification between friends.

---

## 5. UI Components with Liquid Glass Styling

### 5.1 GlassChatHeader (Top Bar)
- **Background**: `Material.thin` or `.glassEffect()`
- **Content**:
    - Back button (left): `FitLinkIcon.backButton`
    - Friend Info (center): Display name and online/typing status
    - Profile Avatar (right): Friend's photo/initials with activity streak badge
- **Typing Indicator**: Animated "..." dots when friend is typing
- **Interaction**: Tap header to push `FriendProfileView`.

### 5.2 GlassChatInputBar (Bottom Bar)
- **Background**: Capsule-shaped `GlassCard` with `GlassTokens.Radius.pill`.
- **Primary Input**: `TextField` with standard `GlassTokens.Padding.standard`.
- **Buttons**:
    - Attachment (left): `+` button opening a glassy menu for:
        - 📷 Images (PhotosUI)
        - 📁 Files (DocumentPicker)
        - 🍽️ Diet Plans
        - 🏋️ Workout Plans
    - Voice (left of send): Hold-to-record microphone button
    - Send (right): `FitLinkIcon.send` inside a prominent glass circle.
- **Voice Recording Mode**: Slide-to-cancel with waveform visualization

### 5.3 Chat Bubbles
- **Sender**: `.green.glassEffect()` with trailing alignment.
- **Recipient**: `.secondary.glassEffect()` with leading alignment.
- **Read Receipts**: Small checkmarks below bubble (✓ sent, ✓✓ delivered, blue ✓✓ read)
- **Reply Preview**: Quoted message shown above the reply with glass background
- **Plan Cards**: Custom `GlassCard` inside the bubble showing the plan title, duration, and a "View Plan" button.
- **Voice Messages**: Waveform visualization with play button, duration shown.
- **Challenge Cards**: Special glass card with challenge details and Accept/Decline buttons.

### 5.4 Typing Indicator
- Animated three-dot bubble with glass effect
- Appears in message list when friend is typing
- Auto-dismisses after 5 seconds of inactivity

### 5.5 Quote/Reply UI
- Swipe right on any message to reply
- Shows quoted message preview in input bar
- Tap reply preview in chat to scroll to original message

---

## 6. Implementation Phases

### Phase 1: Core Infrastructure & Encryption (Week 1-2)
- [ ] Define `FriendChat`, `FriendChatMessage`, `Challenge` models with `toDictionary`/`fromDictionary`.
- [ ] Implement `ChatEncryptionService` with CryptoKit (key generation, encryption, decryption).
- [ ] Create `user_keys` collection and key exchange flow.
- [ ] Store private keys securely in iOS Keychain.
- [ ] Create `ChatService` actor with Firestore real-time listeners (`addSnapshotListener`).
- [ ] Implement `sendMessage` logic with encryption before upload.
- [ ] Implement message decryption on fetch.
- [ ] Implement chat initialization logic in `FriendService`.

### Phase 2: Chat ViewModel & Basic UI (Week 2-3)
- [ ] Create `ChatViewModel` with message fetching, pagination, and decryption.
- [ ] Build `FriendChatView` with `ScrollViewReader` for auto-scrolling to bottom.
- [ ] Implement `GlassChatHeader` with navigation.
- [ ] Add typing indicator state management.
- [ ] Implement read receipt status updates.

### Phase 3: Typing Indicators & Read Receipts (Week 3)
- [ ] Add `typing_status` field updates on text input (debounced).
- [ ] Listen for typing status changes from friend.
- [ ] Build `TypingIndicatorView` with animated glass dots.
- [ ] Update message `status` to `delivered` when fetched by recipient.
- [ ] Update message `status` to `read` when message is visible on screen.
- [ ] Add read receipt UI (checkmarks) to chat bubbles.

### Phase 4: Liquid Glass Input Bar & Attachments (Week 3-4)
- [ ] Build `GlassChatInputBar` following UI_practices.md.
- [ ] Integrate `PhotosUI` for image selection.
- [ ] Implement `PlanSelectionPicker` to browse and select generated plans for sharing.
- [ ] Encrypt attachments before upload.
- [ ] Setup Firebase Storage for encrypted image/file uploads.
- [ ] Build attachment preview bubbles.

### Phase 5: Voice Messages (Week 4)
- [ ] Create `VoiceMessageService` actor for recording/playback.
- [ ] Implement hold-to-record gesture with haptic feedback.
- [ ] Build waveform visualization component.
- [ ] Compress audio (AAC) before encryption and upload.
- [ ] Implement voice message playback in bubbles.
- [ ] Add slide-to-cancel recording gesture.

### Phase 6: Quote/Reply Feature (Week 4-5)
- [ ] Add `reply_to` field to message model.
- [ ] Implement swipe-to-reply gesture on bubbles.
- [ ] Build reply preview component in input bar.
- [ ] Show quoted message preview in reply bubbles.
- [ ] Tap reply to scroll to original message.

### Phase 7: Friend Challenges (Week 5)
- [ ] Create `ChallengeService` actor.
- [ ] Build challenge creation flow (select type, target, duration).
- [ ] Implement challenge message type with Accept/Decline UI.
- [ ] Track challenge progress using HealthKit data.
- [ ] Show challenge status in `FriendProfileView`.
- [ ] Send notification when challenge completes.
- [ ] Celebrate winner with confetti animation.

### Phase 8: Friend Profile & Activity Feed (Week 5-6)
- [ ] Build `FriendProfileView` showing:
    - Activity Summary (Steps, Calories, Exercise Minutes)
    - Streak History
    - Active Challenges
    - Recent Achievements
- [ ] Create `ActivityFeedView` for friend achievements.
- [ ] Implement achievement reactions (tap to react with emoji).
- [ ] Add "Challenge" button to friend profile.
- [ ] Show activity feed cards in chat when friend hits a goal.

### Phase 9: Push Notifications (Week 6)
- [ ] Configure APNs for chat notifications.
- [ ] Send push notification on new message (via Cloud Functions).
- [ ] Include encrypted preview in notification payload.
- [ ] Decrypt and show preview in notification.
- [ ] Deep link from notification to specific chat.
- [ ] Handle notification permissions gracefully.
- [ ] Add in-app notification banner for messages when in different screen.

### Phase 10: Polish & Performance (Week 6-7)
- [ ] Add haptic feedback for message sending/receiving.
- [ ] Implement message pagination for large chats.
- [ ] Cache decrypted messages locally (encrypted at rest).
- [ ] Add empty state for new chats.
- [ ] Implement message retry on failure.
- [ ] Add network connectivity handling.
- [ ] Performance testing with 1000+ messages.

---

## 7. File Structure

```
FitLink/
├── Models/
│   ├── FriendChat.swift               # Chat thread model
│   ├── FriendChatMessage.swift        # Message model
│   ├── Challenge.swift                # Challenge model
│   └── ActivityFeedItem.swift         # Achievement feed item
├── Services/
│   ├── ChatService.swift              # Actor for Firestore/Storage
│   ├── ChatEncryptionService.swift    # E2E encryption logic
│   ├── VoiceMessageService.swift      # Voice recording/playback
│   ├── ChallengeService.swift         # Friend challenges
│   └── ChatNotificationHandler.swift  # In-app notification banners
├── ViewModels/
│   ├── ChatViewModel.swift            # MainActor chat logic
│   ├── FriendProfileViewModel.swift   # Friend activity data
│   └── ActivityFeedViewModel.swift    # Achievement feed logic
├── Views/
│   └── Social/
│       ├── FriendChatView.swift       # Main Chat Screen
│       ├── FriendProfileView.swift    # Friend Activity Detail
│       ├── ActivityFeedView.swift     # Achievement Feed
│       └── Components/
│           ├── GlassChatHeader.swift
│           ├── GlassChatInputBar.swift
│           ├── ChatBubble.swift
│           ├── VoiceBubble.swift
│           ├── PlanShareBubble.swift
│           ├── ChallengeBubble.swift
│           ├── TypingIndicatorView.swift
│           ├── ReplyPreviewView.swift
│           └── VoiceWaveformView.swift
└── Utils/
    ├── GlassChatBubbleModifier.swift  # Custom view modifier
    └── KeychainService.swift          # Secure key storage
```

---

## 8. Dependencies

- **FirebaseFirestore**: Real-time DB for messages.
- **FirebaseStorage**: Encrypted media hosting.
- **CryptoKit**: Native Apple encryption (no third-party).
- **HealthKit**: For activity data sharing and challenges.
- **PhotosUI**: System image picker.
- **AVFoundation**: Voice message recording/playback.
- **UserNotifications**: Push notification handling.

---

## 9. Security Considerations

### 9.1 Encryption
- **E2E Encryption**: All message content encrypted with AES-256-GCM before leaving device.
- **Key Exchange**: X25519 Diffie-Hellman for secure key agreement.
- **Key Storage**: Private keys in iOS Keychain with hardware-backed security.
- **No Plaintext on Server**: Firestore only stores encrypted ciphertext.

### 9.2 Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Chat access: only participants
    match /friend_chats/{chatId} {
      allow read, write: if request.auth.uid in resource.data.participant_ids;
      
      match /friend_messages/{messageId} {
        allow read: if request.auth.uid in get(/databases/$(database)/documents/friend_chats/$(chatId)).data.participant_ids;
        allow create: if request.auth.uid == request.resource.data.sender_id
                      && request.auth.uid in get(/databases/$(database)/documents/friend_chats/$(chatId)).data.participant_ids;
      }
    }
    
    // Public keys: anyone can read, only owner can write
    match /user_keys/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
  }
}
```

### 9.3 Additional Security
- **Blocking**: Messages from blocked users are filtered client-side and rejected by security rules.
- **Rate Limiting**: Cloud Functions rate limit message sending to prevent spam.
- **Media Scanning**: Consider server-side scanning of encrypted media for CSAM (using Apple's on-device scanning or PhotoDNA with user consent).

---

## 10. Future Enhancements (Placeholders)

- [ ] **Message Reactions**: Long-press bubble for glass-morphism emoji picker.
- [ ] **Live Activity**: Dynamic Island support for active chat threads.
- [ ] **Group Chat**: Multi-participant encrypted conversations.
- [ ] **Message Search**: Search through decrypted message history.
- [ ] **Message Forwarding**: Forward messages to other friends.
- [ ] **Double Ratchet**: Per-message key rotation for forward secrecy.
- [ ] **Multi-Device Sync**: Sync encryption keys across user's devices.
- [ ] **QR Code Verification**: Verify friend's encryption keys in-person.
- [ ] **Disappearing Messages**: Auto-delete after configurable time.
- [ ] **Media Gallery**: View all shared images/files in chat.
- [ ] **Link Previews**: Rich previews for shared URLs.
- [ ] **Stickers & GIFs**: Fun visual messages.

---

## 11. Summary

This plan provides a comprehensive roadmap for implementing a secure, feature-rich social chat system within FitLink. Key highlights:

- **End-to-End Encryption** using Apple CryptoKit (AES-256-GCM + X25519)
- **Rich Messaging** with voice messages, read receipts, and quote/reply
- **Social Features** including friend challenges and activity feeds
- **Push Notifications** for real-time engagement
- **Liquid Glass UI** for a premium iOS 26 experience

**Estimated Timeline:** 6-7 weeks for full implementation

**Next Step:** Initialize `ChatEncryptionService` and key generation in Phase 1.
