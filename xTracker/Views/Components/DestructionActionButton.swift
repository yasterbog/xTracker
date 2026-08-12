//
//  DestructionActionButton.swift
//  xTracker
//

import SwiftUI

struct DestructionActionButton: View {
    let title: String
    var isEnabled: Bool = true
    var titleColor: Color? = nil
    let action: () -> Void

    private var resolvedTitleColor: Color {
        if let titleColor {
            return isEnabled ? titleColor : titleColor.opacity(0.35)
        }
        return isEnabled ? .red : .red.opacity(0.35)
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.font(size: 16, weight: .semibold))
                .foregroundStyle(resolvedTitleColor)
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
