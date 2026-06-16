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
                .font(AppFont.font(size: 16, weight: .semibold))
                .foregroundStyle(titleColor)
                .frame(maxWidth: .infinity)
                .frame(height: PrimaryActionButtonMetrics.height)
                .background(
                    PrimaryActionButtonMetrics.shape
                        .fill(Color.clear)
                )
        }
        .buttonStyle(ScalePressButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}
