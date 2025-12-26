import SwiftUI
import UIKit

enum GlassTokens {
    
    enum Radius {
        static let small: CGFloat = 8
        static let card: CGFloat = 16
        static let overlay: CGFloat = 20
        static let pill: CGFloat = 24
    }
    
    enum Layout {
        static let pageHorizontalPadding: CGFloat = 20
        static let pageBottomInset: CGFloat = 16
        
        static let cardSpacing: CGFloat = 16
        
        static func cardSpacing(for screenHeight: CGFloat) -> CGFloat {
            if screenHeight < 700 {
                return 12
            } else if screenHeight < 850 {
                return 16
            } else {
                return 20
            }
        }
    }
}
