# FitLink Agent Guidelines

## Build Commands
- **Build**: `xcodebuild -project FitLink.xcodeproj -scheme FitLink -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- **Test all**: `xcodebuild -project FitLink.xcodeproj -scheme FitLink -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- **Test single**: `xcodebuild test -project FitLink.xcodeproj -scheme FitLink -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitLinkTests/TestClassName/testMethodName`

## Code Style
- **Swift 5**, iOS 18+ with iOS 26 Liquid Glass APIs (use `@available(iOS 26.0, *)` checks)
- **Imports**: `SwiftUI`, `Combine` (for `@Published`/`ObservableObject`), `#if canImport(UIKit)` for UIKit
- Use `// MARK: -` for code organization; avoid unnecessary comments
- **Types**: Actors for services (`actor GeminiAIService`), structs for models, enums with `CodingKeys` for JSON
- **Error handling**: `LocalizedError` with `errorDescription`; never `as any` or force unwraps
- **Naming**: `camelCase` properties, `snake_case` in `CodingKeys` for API mapping
- **UI**: All views use `GlassTokens` for spacing/radii, `GlassCard`/`GlassIconButton` components
- **ViewModels**: `@MainActor class` with `ObservableObject` and `@Published` properties
- Async/await for all network calls with retry logic and exponential backoff
- Firebase Firestore for persistence; documents use `toDictionary()`/`fromDictionary()` pattern
- See `UI_practices.md` for Liquid Glass design patterns and component usage
