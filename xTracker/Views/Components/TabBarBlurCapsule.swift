//
//  TabBarBlurCapsule.swift
//  xTracker
//

import SwiftUI

struct TabBarBlurCapsule: View, Equatable {
    let size: CGSize

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                // Apple Liquid Glass API for custom components.
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular.tint(AppTheme.background.opacity(0.35)))
                    .overlay {
                        Capsule()
                            .fill(AppTheme.background.opacity(0.5))
                    }
            } else {
                // Fallback for older iOS versions.
                GlassBlurPlate(cornerRadius: size.height / 2)
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay {
            Capsule()
                .strokeBorder(GlassCardMetrics.borderGradient, lineWidth: 1)
        }
    }
}
