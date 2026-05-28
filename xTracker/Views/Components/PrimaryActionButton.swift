//
//  PrimaryActionButton.swift
//  xTracker
//

import SwiftUI

enum PrimaryActionButtonMetrics {
    static let height: CGFloat = 52
    static let cornerRadius: CGFloat = 16

    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

struct PrimaryActionButton: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(AppTheme.primaryText)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                }
            }
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: PrimaryActionButtonMetrics.height)
            .background(
                PrimaryActionButtonMetrics.shape
                    .fill(isEnabled ? AppTheme.accent : Color.gray.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}
