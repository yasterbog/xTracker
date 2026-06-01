//
//  TabBarBlurCapsule.swift
//  xTracker
//

import SwiftUI
import UIKit

/// GPU-backed blur chrome for the floating tab bar. `updateUIView` is intentionally empty
/// so drag/press animations do not reconfigure the effect view every frame.
struct TabBarBlurCapsule: UIViewRepresentable, Equatable {
    let size: CGSize

    func makeUIView(context: Context) -> UIVisualEffectView {
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        effectView.clipsToBounds = true
        effectView.isUserInteractionEnabled = false

        let tint = UIView()
        tint.backgroundColor = UIColor(AppTheme.background).withAlphaComponent(0.12)
        tint.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tint.frame = effectView.bounds
        effectView.contentView.addSubview(tint)

        let border = UIView()
        border.isUserInteractionEnabled = false
        border.layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor
        border.layer.borderWidth = 1
        border.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        border.frame = effectView.bounds
        border.backgroundColor = .clear
        effectView.contentView.addSubview(border)

        context.coordinator.tintView = tint
        context.coordinator.borderView = border
        return effectView
    }

    func updateUIView(_ effectView: UIVisualEffectView, context: Context) {
        let radius = size.height / 2
        effectView.layer.cornerRadius = radius
        effectView.frame.size = size

        context.coordinator.tintView?.frame = effectView.bounds
        context.coordinator.borderView?.frame = effectView.bounds
        context.coordinator.borderView?.layer.cornerRadius = radius
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var tintView: UIView?
        weak var borderView: UIView?
    }
}
