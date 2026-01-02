//
//  ThemeColors.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI

struct AppTheme {
    // Dark Gradient Backgrounds
    static let background = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.02, blue: 0.05),
            Color(red: 0.05, green: 0.05, blue: 0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundSolid = Color(red: 0.02, green: 0.02, blue: 0.05)
    static let secondaryBackground = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let cardBackground = Color(red: 0.11, green: 0.11, blue: 0.15)
    static let tertiaryBackground = Color(red: 0.15, green: 0.15, blue: 0.18)

    // Vibrant Modern Accents
    static let accent = Color(red: 0.0, green: 0.82, blue: 0.51) // Bright Emerald
    static let secondaryAccent = Color(red: 0.25, green: 0.65, blue: 1.0) // Vibrant Blue
    static let purpleAccent = Color(red: 0.65, green: 0.45, blue: 1.0) // Bright Purple
    static let pinkAccent = Color(red: 1.0, green: 0.3, blue: 0.6) // Vibrant Pink
    static let orangeAccent = Color(red: 1.0, green: 0.58, blue: 0.0) // Bright Orange

    // Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.75)
    static let textTertiary = Color(red: 0.5, green: 0.5, blue: 0.55)

    // Functional Colors - More Vibrant
    static let income = Color(red: 0.0, green: 0.85, blue: 0.45) // Bright Green
    static let expense = Color(red: 1.0, green: 0.27, blue: 0.32) // Bright Red
    static let warning = Color(red: 1.0, green: 0.75, blue: 0.0) // Bright Yellow

    // Modern Gradient Backgrounds
    static let cardGradient = LinearGradient(
        colors: [
            Color(red: 0.12, green: 0.12, blue: 0.16),
            Color(red: 0.09, green: 0.09, blue: 0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.0, green: 0.82, blue: 0.51),
            Color(red: 0.0, green: 0.95, blue: 0.6)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let incomeGradient = LinearGradient(
        colors: [
            Color(red: 0.0, green: 0.85, blue: 0.45),
            Color(red: 0.15, green: 0.95, blue: 0.55)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let expenseGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.27, blue: 0.32),
            Color(red: 1.0, green: 0.4, blue: 0.45)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let blueGradient = LinearGradient(
        colors: [
            Color(red: 0.25, green: 0.65, blue: 1.0),
            Color(red: 0.4, green: 0.75, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let purpleGradient = LinearGradient(
        colors: [
            Color(red: 0.65, green: 0.45, blue: 1.0),
            Color(red: 0.75, green: 0.55, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.15),
            Color.white.opacity(0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Mesh Gradient Background (iOS 18+)
    static let meshBackground = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.02, blue: 0.08),
            Color(red: 0.05, green: 0.03, blue: 0.1),
            Color(red: 0.03, green: 0.05, blue: 0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// Custom modifiers for consistent styling
struct ModernCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardGradient)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
            .shadow(color: AppTheme.accent.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(AppTheme.glassGradient)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 25, x: 0, y: 12)
    }
}

struct NeonGlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.4), radius: radius * 1.5, x: 0, y: 0)
            .shadow(color: color.opacity(0.2), radius: radius * 2, x: 0, y: 0)
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .rotationEffect(.degrees(30))
                        .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func modernCardStyle() -> some View {
        modifier(ModernCardModifier())
    }

    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }

    func neonGlow(color: Color = AppTheme.accent, radius: CGFloat = 8) -> some View {
        modifier(NeonGlowModifier(color: color, radius: radius))
    }

    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    // Helper to make numbers look modern
    func monospacedDigit() -> some View {
        self.font(.system(.body, design: .rounded).monospacedDigit())
    }

    // Animated button press effect
    func pressEffect() -> some View {
        self.buttonStyle(PressEffectButtonStyle())
    }

    // Gradient text
    func gradientForeground(_ gradient: LinearGradient) -> some View {
        self.overlay(gradient)
            .mask(self)
    }
}

struct PressEffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}