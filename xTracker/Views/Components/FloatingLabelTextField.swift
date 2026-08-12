//
//  FloatingLabelTextField.swift
//  xTracker
//

import SwiftUI

struct FloatingLabelTextField: View {
    let label: String
    @Binding var text: String
    var isEditable: Bool = true
    var fieldBackgroundColor: Color = AppTheme.subtleSurfaceBackground
    var trailingIconAsset: String? = nil
    var trailingIconSuccessAsset: String? = nil
    var isTrailingIconSuccess: Bool = false
    var trailingIconColor: Color = AppTheme.accent
    var trailingIconSuccessColor: Color = AppTheme.successGreen
    var textInputAutocapitalization: TextInputAutocapitalization = .sentences
    var onTrailingTap: (() -> Void)? = nil

    private let trailingIconAnimation = Animation.easeOut(duration: 0.08)

    @FocusState private var isFocused: Bool

    private var isFloating: Bool {
        isFocused || !text.isEmpty
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(fieldBackgroundColor)

            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    Text(label)
                        .font(AppFont.font(size: isFloating ? 11 : 16, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .offset(y: isFloating ? -9 : 0)
                        .animation(.easeOut(duration: 0.12), value: isFloating)
                        .allowsHitTesting(false)

                    if isEditable {
                        TextField("", text: $text)
                            .font(AppFont.font(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .focused($isFocused)
                            .offset(y: isFloating ? 7 : 0)
                            .opacity(isFloating ? 1 : 0.01)
                            .textInputAutocapitalization(textInputAutocapitalization)
                            .autocorrectionDisabled()
                    } else if isFloating {
                        Text(text)
                            .font(AppFont.font(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .offset(y: 7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let trailingIconAsset, let onTrailingTap {
                    Button(action: onTrailingTap) {
                        trailingIconView(defaultAsset: trailingIconAsset)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: PrimaryActionButtonMetrics.height)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            guard isEditable else { return }
            isFocused = true
        }
    }

    @ViewBuilder
    private func trailingIconView(defaultAsset: String) -> some View {
        let iconSize: CGFloat = 18

        if let trailingIconSuccessAsset {
            ZStack {
                trailingIconImage(
                    asset: defaultAsset,
                    color: trailingIconColor,
                    size: iconSize
                )
                .opacity(isTrailingIconSuccess ? 0 : 1)

                trailingIconImage(
                    asset: trailingIconSuccessAsset,
                    color: trailingIconSuccessColor,
                    size: iconSize
                )
                .opacity(isTrailingIconSuccess ? 1 : 0)
            }
            .animation(trailingIconAnimation, value: isTrailingIconSuccess)
        } else {
            trailingIconImage(
                asset: defaultAsset,
                color: trailingIconColor,
                size: iconSize
            )
        }
    }

    private func trailingIconImage(asset: String, color: Color, size: CGFloat) -> some View {
        Image(asset)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}

struct FloatingLabelReadOnlyField: View {
    let label: String
    let value: String
    var fieldBackgroundColor: Color = AppTheme.subtleSurfaceBackground
    var trailingIconAsset: String? = nil
    var trailingIconSuccessAsset: String? = nil
    var isTrailingIconSuccess: Bool = false
    var trailingIconColor: Color = AppTheme.accent
    var trailingIconSuccessColor: Color = AppTheme.successGreen
    var onTrailingTap: (() -> Void)? = nil

    var body: some View {
        FloatingLabelTextField(
            label: label,
            text: .constant(value),
            isEditable: false,
            fieldBackgroundColor: fieldBackgroundColor,
            trailingIconAsset: trailingIconAsset,
            trailingIconSuccessAsset: trailingIconSuccessAsset,
            isTrailingIconSuccess: isTrailingIconSuccess,
            trailingIconColor: trailingIconColor,
            trailingIconSuccessColor: trailingIconSuccessColor,
            onTrailingTap: onTrailingTap
        )
    }
}
