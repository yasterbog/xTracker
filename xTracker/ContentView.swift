//
//  ContentView.swift
//  xTracker
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var gradientStart: UnitPoint = .top
    @State private var gradientEnd: UnitPoint = .bottomTrailing

    init() {
        UITabBar.appearance().isHidden = true
    }

    private func animateGradient() {
        let starts: [UnitPoint] = [.topLeading, .topTrailing, .top]
        let ends: [UnitPoint] = [.bottomLeading, .bottomTrailing, .bottom, .leading, .trailing]

        withAnimation(.easeInOut(duration: 2.0)) {
            gradientStart = starts.randomElement() ?? .top
            gradientEnd = ends.randomElement() ?? .bottomTrailing
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView(
                gradientStart: gradientStart,
                gradientEnd: gradientEnd
            )
            .tag(0)

            StatisticsView(
                gradientStart: gradientStart,
                gradientEnd: gradientEnd,
                onAnimateGradient: animateGradient
            )
            .tag(1)

            SettingsView(
                gradientStart: gradientStart,
                gradientEnd: gradientEnd
            )
            .tag(2)
        }
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .bottom) {
            FloatingTabBar(selectedTab: $selectedTab)
                .offset(y: 12)
                .allowsHitTesting(true)
        }
        .onChange(of: selectedTab) { _ in
            animateGradient()
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selectedTab: Int

    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false
    @State private var touchStartIndex: Int = 0
    @State private var isTouching = false
    @State private var pillStretchX: CGFloat = 1
    @State private var pillStretchY: CGFloat = 1
    @State private var pillStretchAnchor: UnitPoint = .center
    @State private var pillStretchResetTask: Task<Void, Never>?

    private let itemWidth: CGFloat = 72
    private let itemSpacing: CGFloat = 4
    private let tabCount = 3
    private let containerPadding: CGFloat = 4
    /// Blur strength: `.ultraThinMaterial` (lightest) → `.thinMaterial` → `.regularMaterial` (strongest).
    private let barGlassMaterial: Material = .ultraThinMaterial
    private let barGlassTintAlpha: CGFloat = 0.12
    private let barGlassHighlightAlpha: CGFloat = 0.03
    private let pressedScale: CGFloat = 1.08
    private let pressSpring = Animation.spring(response: 0.42, dampingFraction: 0.45)
    private let pillSpring = Animation.spring(response: 0.28, dampingFraction: 0.9)
    private let pillShapeRelaxSpring = Animation.spring(response: 0.34, dampingFraction: 0.72)
    private let dragMovementThreshold: CGFloat = 6

    let tabs = [
        ("icon_calendar", "icon_calendar_outline"),
        ("icon_stats", "icon_stats_outline"),
        ("icon_settings", "icon_settings_outline"),
    ]

    private var segmentWidth: CGFloat { itemWidth + itemSpacing }

    private var displayIndex: CGFloat {
        let base = CGFloat(isDragging ? touchStartIndex : selectedTab)
        let offset = isDragging ? dragTranslation / segmentWidth : 0
        return min(max(base + offset, 0), CGFloat(tabCount - 1))
    }

    private var pillOffsetX: CGFloat {
        displayIndex * segmentWidth
    }

    var body: some View {
        tabBarContent
            .scaleEffect(isTouching ? pressedScale : 1)
            .animation(pressSpring, value: isTouching)
    }

    private var tabBarContent: some View {
        HStack(spacing: itemSpacing) {
            ForEach(0..<tabCount, id: \.self) { index in
                tabItem(for: index)
            }
        }
        .background(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: itemWidth, height: 48)
                .scaleEffect(x: pillStretchX, y: pillStretchY, anchor: pillStretchAnchor)
                .offset(x: pillOffsetX)
                .animation(isDragging ? nil : pillSpring, value: pillOffsetX)
                .animation(isDragging ? nil : pillSpring, value: pillStretchX)
                .animation(isDragging ? nil : pillSpring, value: pillStretchY)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, containerPadding)
        .padding(.vertical, containerPadding)
        .background {
            Capsule()
                .fill(barGlassMaterial)
                .overlay {
                    Capsule()
                        .fill(AppTheme.background.opacity(barGlassTintAlpha))
                }
                .overlay {
                    Capsule()
                        .fill(Color.white.opacity(barGlassHighlightAlpha))
                }
        }
        .overlay {
            Capsule()
                .stroke(GlassCardMetrics.borderGradient, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        .contentShape(Capsule())
        .gesture(tabBarDragGesture)
    }

    private func tabItem(for index: Int) -> some View {
        let filledIndex = isTouching ? touchStartIndex : selectedTab
        let usesActiveIcon = index == filledIndex

        return Image(usesActiveIcon ? tabs[index].0 : tabs[index].1)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .frame(width: itemWidth, height: 48)
            .allowsHitTesting(false)
    }

    private func tabIndex(at locationX: CGFloat) -> Int {
        let adjustedX = locationX - containerPadding
        guard adjustedX >= 0 else { return 0 }
        let index = Int(adjustedX / segmentWidth)
        return min(max(index, 0), tabCount - 1)
    }

    private func beginPillStretch(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex != toIndex else { return }

        let distance = abs(toIndex - fromIndex)
        pillStretchAnchor = toIndex > fromIndex ? .leading : .trailing
        pillStretchX = 1.02 + 0.04 * CGFloat(max(0, distance - 1))
        pillStretchY = 0.95
    }

    private func resetPillStretch() {
        pillStretchAnchor = .center
        pillStretchX = 1
        pillStretchY = 1
    }

    private func schedulePillStretchReset() {
        pillStretchResetTask?.cancel()
        pillStretchResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(pillShapeRelaxSpring) {
                resetPillStretch()
            }
        }
    }

    private func commitTabChange(from fromIndex: Int, to toIndex: Int, updates: () -> Void) {
        if fromIndex != toIndex {
            beginPillStretch(from: fromIndex, to: toIndex)
        }

        withAnimation(pillSpring) {
            updates()
        }

        if fromIndex != toIndex {
            schedulePillStretchReset()
        }
    }

    private var tabBarDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if !isTouching {
                    isTouching = true
                    touchStartIndex = tabIndex(at: value.startLocation.x)
                }

                let moved = hypot(value.translation.width, value.translation.height) > dragMovementThreshold

                if moved {
                    if !isDragging {
                        isDragging = true
                    }
                    dragTranslation = value.translation.width
                }
            }
            .onEnded { value in
                let moved = hypot(value.translation.width, value.translation.height) > dragMovementThreshold

                if !moved {
                    let index = tabIndex(at: value.startLocation.x)
                    let fromIndex = selectedTab
                    commitTabChange(from: fromIndex, to: index) {
                        if index != selectedTab {
                            selectedTab = index
                        }
                        isTouching = false
                    }
                    dragTranslation = 0
                    isDragging = false
                    return
                }

                let base = CGFloat(touchStartIndex) + value.translation.width / segmentWidth
                let projected = base + value.predictedEndTranslation.width / segmentWidth * 0.15
                let targetIndex = Int(round(min(max(projected, 0), CGFloat(tabCount - 1))))
                let fromIndex = selectedTab

                commitTabChange(from: fromIndex, to: targetIndex) {
                    dragTranslation = 0
                    selectedTab = targetIndex
                    isDragging = false
                    isTouching = false
                }
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(EventStore())
        .environmentObject(AuthService())
        .environmentObject(UserService())
}
