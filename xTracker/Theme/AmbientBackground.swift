//
//  AmbientBackground.swift
//  xTracker
//

import SwiftUI

/// Top atmospheric glow — three soft pink/red blobs over the app background.
struct AmbientBackground: View {
    var startPoint: UnitPoint = .top
    var endPoint: UnitPoint = .bottom

    private static let pink = AppTheme.accent
    private static let deepRed = Color(hex: "#C0134A")

    private let width = UIScreen.main.bounds.width

    var body: some View {
        ZStack(alignment: .top) {
            mainBlob
            secondaryBlob
            tertiaryBlob
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Main blob — upper area, strongest presence
    private var mainBlob: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Self.pink.opacity(0.7),
                        Self.pink.opacity(0.28),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.55
                )
            )
            .frame(width: width * 1.1, height: 340)
            .blur(radius: 72)
            .offset(x: width * 0.08, y: -80)
    }

    /// Secondary blob — right hotspot
    private var secondaryBlob: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Self.deepRed.opacity(0.45),
                        Self.pink.opacity(0.2),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.42
                )
            )
            .frame(width: width * 0.82, height: 280)
            .blur(radius: 64)
            .offset(x: width * 0.28, y: -20)
    }

    /// Tertiary blob — left fill
    private var tertiaryBlob: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Self.pink.opacity(0.25),
                        Self.deepRed.opacity(0.1),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.38
                )
            )
            .frame(width: width * 0.7, height: 220)
            .blur(radius: 56)
            .offset(x: -width * 0.2, y: 40)
    }
}

extension View {
    /// Standard chrome for Calendar / Statistics / Settings: ambient + content.
    func mainScreenAtmosphere<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            AmbientBackground()
                .ignoresSafeArea()

            content()
        }
        .background(AppTheme.background)
    }
}
