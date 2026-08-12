//
//  TabBarBlurCapsule.swift
//  xTracker
//

import SwiftUI

struct TabBarBlurCapsule: View, Equatable {
    let size: CGSize

    var body: some View {
        GlassBlurPlate(cornerRadius: size.height / 2)
            .frame(width: size.width, height: size.height)
            .overlay {
                Capsule()
                    .strokeBorder(GlassCardMetrics.borderGradient, lineWidth: 1)
            }
    }
}
