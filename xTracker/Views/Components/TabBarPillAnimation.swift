//
//  TabBarPillAnimation.swift
//  xTracker
//

import SwiftUI

enum TabBarPillAnimation {
    static let icon = Animation.easeInOut(duration: 0.12)
    static let move = Animation.spring(response: 0.38, dampingFraction: 0.84)
    static let stretchSnap = Animation.spring(response: 0.24, dampingFraction: 0.68)
    static let stretchRelax = Animation.spring(response: 0.30, dampingFraction: 0.74)
}

struct PillStretchState: Equatable {
    var x: CGFloat
    var y: CGFloat
    var anchor: UnitPoint

    static let neutral = PillStretchState(x: 1, y: 1, anchor: .center)
}
