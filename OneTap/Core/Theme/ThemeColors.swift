//
//  ThemeColors.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI

struct AppTheme {
    // Pure Black Backgrounds (Modern/AMOLED)
    static let background = Color.black
    static let secondaryBackground = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let cardBackground = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let tertiaryBackground = Color(red: 0.15, green: 0.15, blue: 0.16)
    
    // Modern Accents
    static let accent = Color(red: 0.05, green: 0.75, blue: 0.45) // Emerald Green
    static let secondaryAccent = Color(red: 0.2, green: 0.6, blue: 0.9) // Soft Blue
    static let purpleAccent = Color(red: 0.6, green: 0.4, blue: 0.9) // Muted Purple
    
    // Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.65, green: 0.65, blue: 0.7)
    static let textTertiary = Color(red: 0.4, green: 0.4, blue: 0.45)
    
    // Functional Colors
    static let income = Color(red: 0.1, green: 0.7, blue: 0.4) // Balanced green
    static let expense = Color(red: 0.9, green: 0.3, blue: 0.3) // Balanced red
    static let warning = Color(red: 1.0, green: 0.7, blue: 0.2)
    
    // Gradient Backgrounds
    static let cardGradient = LinearGradient(
        colors: [cardBackground, Color(red: 0.09, green: 0.09, blue: 0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [accent, Color(red: 0.1, green: 0.8, blue: 0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let glassGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.1),
            Color.white.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// Custom modifiers for consistent styling
struct ModernCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                AppTheme.cardBackground.opacity(0.7)
                    .blur(radius: 20)
            )
            .background(AppTheme.glassGradient)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
    }
}

extension View {
    func modernCardStyle() -> some View {
        modifier(ModernCardModifier())
    }
    
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
    
    // Helper to make numbers look modern
    func monospacedDigit() -> some View {
        self.font(.system(.body, design: .rounded))
    }
}