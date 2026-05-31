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
    static let disabledFill = Color(hex: "#48484A")
    static let disabledText = Color.white.opacity(0.55)

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

    private var isInteractive: Bool {
        isEnabled && !isLoading
    }

    var body: some View {
        Button(action: action) {
            buttonLabel
        }
        .buttonStyle(PrimaryActionButtonStyle(isEnabled: isEnabled, isLoading: isLoading))
        .allowsHitTesting(isInteractive)
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
        .foregroundStyle(isEnabled && !isLoading ? AppTheme.primaryText : PrimaryActionButtonMetrics.disabledText)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: expandsHorizontally ? .infinity : nil)
        .frame(height: PrimaryActionButtonMetrics.height)
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    let isEnabled: Bool
    let isLoading: Bool

    private var isInteractive: Bool {
        isEnabled && !isLoading
    }

    private var usesAccentFill: Bool {
        isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                ZStack {
                    PrimaryActionButtonMetrics.shape
                        .fill(usesAccentFill ? AppTheme.accent : PrimaryActionButtonMetrics.disabledFill)

                    if configuration.isPressed, isInteractive {
                        PrimaryActionButtonMetrics.shape
                            .fill(Color.black.opacity(PrimaryActionButtonMetrics.pressedOverlayOpacity))
                    }
                }
            }
            .scaleEffect(configuration.isPressed && isInteractive ? 0.98 : 1)
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
