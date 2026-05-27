//
//  GlassCard.swift
//  xTracker
//

import SwiftUI

enum GlassCardMetrics {
    static let cornerRadius: CGFloat = 24

    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    static var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.18),
                Color.white.opacity(0.03),
                Color.white.opacity(0.08),
                Color.white.opacity(0.03),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct GlassCardStyle: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .glassCardChrome()
    }
}

extension View {
    func glassCard(padding: CGFloat = 16) -> some View {
        modifier(GlassCardStyle(padding: padding))
    }

    func glassSectionCard() -> some View {
        padding(.horizontal, 18)
            .padding(.vertical, 18)
            .glassCardChrome()
    }

    func glassCardChrome() -> some View {
        background(Color.white.opacity(0.07))
            .clipShape(GlassCardMetrics.shape)
            .overlay(
                GlassCardMetrics.shape.stroke(GlassCardMetrics.borderGradient, lineWidth: 1)
            )
    }

    func glassSelectableSurface(isSelected: Bool, selectedColor: Color = AppTheme.accent) -> some View {
        background(GlassCardMetrics.shape.fill(isSelected ? selectedColor : Color.white.opacity(0.07)))
            .overlay(
                GlassCardMetrics.shape.stroke(
                    isSelected ? AnyShapeStyle(selectedColor) : AnyShapeStyle(GlassCardMetrics.borderGradient),
                    lineWidth: 1
                )
            )
    }
}
