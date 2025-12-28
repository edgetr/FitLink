import SwiftUI
import UIKit

enum GlassTokens {
    
    // MARK: - Corner Radii
    
    enum Radius {
        static let small: CGFloat = 8
        static let card: CGFloat = 16
        static let overlay: CGFloat = 20
        static let pill: CGFloat = 24
    }
    
    // MARK: - Layout & Spacing
    
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
    
    // MARK: - Padding (Vertical Spacing Scale from UI_practices.md)
    
    enum Padding {
        /// 8pt: Between related elements (Title/Subtitle)
        static let small: CGFloat = 8
        /// 12pt: Compact card spacing / internal card padding in compact mode
        static let compact: CGFloat = 12
        /// 16pt: Standard component spacing / internal card padding
        static let standard: CGFloat = 16
        /// 24pt: Section spacing
        static let section: CGFloat = 24
        /// 32pt: Large layout breaks
        static let large: CGFloat = 32
        /// 40pt: Extra large spacing for hero sections
        static let hero: CGFloat = 40
    }
    
    // MARK: - Icon Sizes
    
    enum IconSize {
        /// Small icons (e.g., bar chart labels): 8-10pt
        static let tiny: CGFloat = 10
        /// Caption icons: 14pt
        static let caption: CGFloat = 14
        /// Body icons: 17pt
        static let body: CGFloat = 17
        /// Title icons: 22pt
        static let title: CGFloat = 22
        /// Large icons (e.g., card icons): 32pt
        static let large: CGFloat = 32
        /// Icon inside colored circle (metric cards): 36pt
        static let metric: CGFloat = 36
        /// Hero icons (e.g., main feature icons): 48pt
        static let hero: CGFloat = 48
        /// Extra large icons for empty states: 60pt
        static let emptyState: CGFloat = 60
    }
    
    // MARK: - Metric Card Sizes
    
    enum MetricCard {
        /// Icon background circle size
        static let iconCircleSize: CGFloat = 80
        /// Primary value font size (Dynamic Type aware)
        static let primaryValueSize: CGFloat = 48
        /// Bar width in hourly charts
        static let barWidth: CGFloat = 28
        /// Minimum bar height
        static let minBarHeight: CGFloat = 4
        /// Chart container height
        static let chartHeight: CGFloat = 240
    }
    
    // MARK: - Typography Sizes (for icons that shouldn't scale with Dynamic Type)
    
    enum FixedTypography {
        /// Tiny labels in charts: 8pt
        static let chartValueLabel: CGFloat = 8
        /// Small labels in charts: 9pt
        static let chartAxisLabel: CGFloat = 9
        /// Small chart labels: 10pt
        static let chartLabel: CGFloat = 10
    }
}
