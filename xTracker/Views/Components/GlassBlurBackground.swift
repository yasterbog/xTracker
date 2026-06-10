//
//  GlassBlurBackground.swift
//  xTracker
//

import SwiftUI
import UIKit

/// Ultra-thin material + tint (same chrome as the floating tab bar), without a border.
struct GlassBlurBackground: UIViewRepresentable, Equatable {
    var cornerRadius: CGFloat

    func makeUIView(context: Context) -> UIVisualEffectView {
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        effectView.clipsToBounds = true
        effectView.isUserInteractionEnabled = false
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let tint = UIView()
        tint.backgroundColor = UIColor(AppTheme.background).withAlphaComponent(0.12)
        tint.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        effectView.contentView.addSubview(tint)

        context.coordinator.tintView = tint
        return effectView
    }

    func updateUIView(_ effectView: UIVisualEffectView, context: Context) {
        effectView.layer.cornerRadius = cornerRadius
        context.coordinator.tintView?.frame = effectView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var tintView: UIView?
    }
}

/// Sizes the UIKit blur to its SwiftUI container (background without a frame often collapses to zero).
struct GlassBlurPlate: View {
    var cornerRadius: CGFloat

    var body: some View {
        GlassBlurBackground(cornerRadius: cornerRadius)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Same chrome as the floating tab bar, for arbitrary corner radii.
struct FloatingChromePlate: View {
    var cornerRadius: CGFloat

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular.tint(AppTheme.background.opacity(0.35)))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(AppTheme.background.opacity(0.5))
                    }
            } else {
                GlassBlurPlate(cornerRadius: cornerRadius)
            }
        }
    }
}
