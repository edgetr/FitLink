import SwiftUI

// MARK: - Conditional View Modifier Extension

extension View {
    /// Apply a transformation if a condition is true
    /// - Parameters:
    ///   - condition: The condition to evaluate
    ///   - transform: The transformation to apply when condition is true
    /// - Returns: The transformed view if condition is true, otherwise the original view
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply one transformation if condition is true, another if false
    /// - Parameters:
    ///   - condition: The condition to evaluate
    ///   - ifTrue: The transformation to apply when condition is true
    ///   - ifFalse: The transformation to apply when condition is false
    /// - Returns: The appropriately transformed view
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        ifTrue: (Self) -> TrueContent,
        ifFalse: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTrue(self)
        } else {
            ifFalse(self)
        }
    }
    
    /// Apply a transformation if an optional value is non-nil
    /// - Parameters:
    ///   - value: The optional value to unwrap
    ///   - transform: The transformation to apply with the unwrapped value
    /// - Returns: The transformed view if value exists, otherwise the original view
    @ViewBuilder
    func ifLet<Value, Content: View>(_ value: Value?, transform: (Self, Value) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
    
    /// Apply a modifier only on iOS 17+
    @ViewBuilder
    func iOS17(_ transform: (Self) -> some View) -> some View {
        if #available(iOS 17.0, *) {
            transform(self)
        } else {
            self
        }
    }
    
    /// Hide a view conditionally
    /// - Parameter hidden: Whether to hide the view
    /// - Returns: The view, possibly hidden
    @ViewBuilder
    func hidden(_ hidden: Bool) -> some View {
        if hidden {
            self.hidden()
        } else {
            self
        }
    }
    
    /// Apply a view modifier only when in debug builds
    @ViewBuilder
    func debugOnly(_ transform: (Self) -> some View) -> some View {
        #if DEBUG
        transform(self)
        #else
        self
        #endif
    }
}

// MARK: - Optional Binding Extension

extension View {
    /// Bind to an optional value, providing a non-nil binding
    /// - Parameters:
    ///   - binding: The optional binding
    ///   - defaultValue: The default value when nil
    /// - Returns: A non-optional binding
    func unwrap<T>(_ binding: Binding<T?>, default defaultValue: T) -> Binding<T> {
        Binding(
            get: { binding.wrappedValue ?? defaultValue },
            set: { binding.wrappedValue = $0 }
        )
    }
}

// MARK: - Animation Extension

extension View {
    /// Apply animation only if a condition is true
    /// - Parameters:
    ///   - animation: The animation to apply
    ///   - condition: Whether to apply the animation
    /// - Returns: The view with or without animation
    @ViewBuilder
    func animation(_ animation: Animation?, when condition: Bool) -> some View {
        if condition {
            self.animation(animation, value: condition)
        } else {
            self
        }
    }
}

// MARK: - Frame Extensions

extension View {
    /// Apply a frame only if the size is non-nil
    /// - Parameters:
    ///   - width: Optional width
    ///   - height: Optional height
    ///   - alignment: The alignment (default: center)
    /// - Returns: The view with frame applied if dimensions provided
    @ViewBuilder
    func frameIfNeeded(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        if width != nil || height != nil {
            self.frame(width: width, height: height, alignment: alignment)
        } else {
            self
        }
    }
    
    /// Apply max frame constraints
    /// - Parameters:
    ///   - maxWidth: Maximum width
    ///   - maxHeight: Maximum height
    /// - Returns: The view with max frame constraints
    func maxFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        self.frame(maxWidth: width, maxHeight: height)
    }
}

// MARK: - Accessibility Extensions

extension View {
    func accessibilityConfigured(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .ifLet(hint) { view, hintValue in
                view.accessibilityHint(hintValue)
            }
            .accessibilityAddTraits(traits)
    }
    
    func accessibilityConfiguredButton(
        label: String,
        hint: String? = nil
    ) -> some View {
        accessibilityConfigured(label: label, hint: hint, traits: .isButton)
    }
    
    func accessibilityConfiguredHeader(_ label: String) -> some View {
        accessibilityConfigured(label: label, traits: .isHeader)
    }
    
    func accessibilityConfiguredImage(_ label: String) -> some View {
        accessibilityConfigured(label: label, traits: .isImage)
    }
}

// MARK: - Padding Extensions

extension View {
    func symmetricPadding(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> some View {
        self
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
    }
}
