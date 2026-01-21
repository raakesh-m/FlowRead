// Theme.swift
// FlowRead - Color theme and design tokens

import SwiftUI

// MARK: - Color Extensions

extension Color {
    // Background colors
    static let background = Color("Background", bundle: nil)
    static let surface = Color("Surface", bundle: nil)
    static let readingBackground = Color("ReadingBackground", bundle: nil)
    
    // Text colors
    static let textPrimary = Color("TextPrimary", bundle: nil)
    static let textSecondary = Color("TextSecondary", bundle: nil)
    static let textTertiary = Color("TextTertiary", bundle: nil)
    
    // Accent colors
    static let accentBlue = Color("AccentBlue", bundle: nil)
    static let accentPurple = Color("AccentPurple", bundle: nil)
    
    // Highlight colors
    static let highlightActive = Color("HighlightActive", bundle: nil)
    static let highlightHover = Color("HighlightHover", bundle: nil)
    
    // Border colors
    static let border = Color("Border", bundle: nil)
    
    // Fallback initializers for when asset catalog is not available
    static var backgroundFallback: Color {
        Color(nsColor: NSColor.windowBackgroundColor)
    }
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool = true
    
    init() {
        // Detect system appearance
        if let appearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
            isDarkMode = appearance == .darkAqua
        }
    }
    
    func toggleTheme() {
        isDarkMode.toggle()
        applyTheme()
    }
    
    private func applyTheme() {
        NSApp.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
    }
}

// MARK: - Design Tokens

struct DesignTokens {
    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    
    // Border radius
    static let radiusSM: CGFloat = 4
    static let radiusMD: CGFloat = 8
    static let radiusLG: CGFloat = 12
    static let radiusXL: CGFloat = 16
    
    // Font sizes
    static let fontSizeCaption: CGFloat = 12
    static let fontSizeBody: CGFloat = 16
    static let fontSizeReading: CGFloat = 18
    static let fontSizeHeadline: CGFloat = 20
    static let fontSizeTitle: CGFloat = 28
    
    // Animation durations
    static let animationFast: Double = 0.15
    static let animationNormal: Double = 0.25
    static let animationSlow: Double = 0.4
}
