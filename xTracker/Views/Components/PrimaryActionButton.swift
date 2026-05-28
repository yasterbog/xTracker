//
//  PrimaryActionButton.swift
//  xTracker
//

import SwiftUI

enum PrimaryActionButtonMetrics {
    static let height: CGFloat = 56
    static let cornerRadius: CGFloat = 48
    static let compactHorizontalPadding: CGFloat = 24
    static let pressedOverlayOpacity: Double = 0.22

    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

struct PrimaryActionButton: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var expandsHorizontally: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            buttonLabel
        }
        .buttonStyle(PrimaryActionButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }

    private var horizontalPadding: CGFloat {
        expandsHorizontally ? 0 : PrimaryActionButtonMetrics.compactHorizontalPadding
    }

    private var buttonLabel: some View {
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
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: expandsHorizontally ? .infinity : nil)
        .frame(height: PrimaryActionButtonMetrics.height)
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                ZStack {
                    PrimaryActionButtonMetrics.shape
                        .fill(isEnabled ? AppTheme.accent : Color.gray.opacity(0.35))

                    if configuration.isPressed, isEnabled {
                        PrimaryActionButtonMetrics.shape
                            .fill(Color.black.opacity(PrimaryActionButtonMetrics.pressedOverlayOpacity))
                    }
                }
            }
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func primaryActionButtonFloatingShadow() -> some View {
        background(alignment: .bottom) {
            PrimaryActionButtonMetrics.shape
                .fill(Color.black.opacity(0.65))
                .scaleEffect(1.32, anchor: .center)
                .blur(radius: 24)
                .offset(y: 0)
                .allowsHitTesting(false)
        }
    }
}
