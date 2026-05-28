//
//  DestructionActionButton.swift
//  xTracker
//

import SwiftUI

struct DestructionActionButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    private var titleColor: Color {
        isEnabled ? .red : .red.opacity(0.35)
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(titleColor)
                .frame(maxWidth: .infinity)
                .frame(height: PrimaryActionButtonMetrics.height)
                .background(
                    PrimaryActionButtonMetrics.shape
                        .fill(Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}
