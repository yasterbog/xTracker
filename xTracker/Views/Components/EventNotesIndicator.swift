//
//  EventNotesIndicator.swift
//  xTracker
//

import SwiftUI

/// Subtle “has notes” affordance — tertiary SF Symbol, aligned with row titles (Apple list style).
struct EventNotesIndicator: View {
    private let size: CGFloat = 22
    private let fillColor = Color(red: 1, green: 0.82, blue: 0.28).opacity(0.2)
    private let strokeColor = Color(red: 1, green: 0.88, blue: 0.42).opacity(0.3)
    private let iconColor = Color(red: 1, green: 0.9, blue: 0.5).opacity(0.88)

    var body: some View {
        Image(systemName: "text.quote")
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 11, weight: .medium, design: .default))
            .foregroundStyle(iconColor)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(fillColor)
            )
            .overlay(
                Circle()
                    .stroke(strokeColor, lineWidth: 0.5)
            )
            .accessibilityLabel("Есть заметка")
    }
}
