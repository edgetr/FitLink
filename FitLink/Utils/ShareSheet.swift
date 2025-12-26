import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    var onComplete: ((UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Void)? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = onComplete
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let items: [Any]
    var onComplete: ((Bool) -> Void)? = nil
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ShareSheet(items: items) { _, completed, _, _ in
                    onComplete?(completed)
                }
            }
    }
}

extension View {
    func shareSheet(
        isPresented: Binding<Bool>,
        items: [Any],
        onComplete: ((Bool) -> Void)? = nil
    ) -> some View {
        modifier(ShareSheetModifier(isPresented: isPresented, items: items, onComplete: onComplete))
    }
}
